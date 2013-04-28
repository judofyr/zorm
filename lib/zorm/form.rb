require 'set'

module Zorm
  class Form
    attr_accessor :input, :_on_error

    def initialize(input)
      @input = input
    end

    def self.field_class
      @field_class || Field
    end

    class << self
      attr_writer :field_class
    end

    def self.inherited(klass)
      super
      klass.field_class = Class.new(klass.field_class)
    end

    def self.define_helper(name, &blk)
      field_class.class_eval do
        define_method(name, &blk)
      end
    end

    def self.define_validation(name, &blk)
      define_helper(name) do |*args, &msg|
        msg ||= [name, *args]
        validate(msg) do |value|
          instance_exec(value, *args, &blk)
        end
      end
    end

    def self.define_set_validation(name, &blk)
      define_helper(name) do |*args, &msg|
        msg ||= [name, *args]
        validate_set(msg) do |value|
          instance_exec(value, *args, &blk)
        end
      end
    end

    def field_class
      self.class.field_class
    end

    def fields
      @_fields ||= {}
    end

    def forms
      @_forms ||= {}
    end

    def formsets
      @_formsets ||= {}
    end

    def output
      res = {}
      fields.each do |name, field|
        res[field.name] = field.value unless field.ignored?
      end
      formsets.each do |name, form|
        res[form.name] = form.value.map(&:output)
      end
      forms.each do |name, form|
        res[name] = form.output
      end
      res = @_mapper.call(res) if @_mapper
      res
    end

    def map(&blk)
      raise ArgumentError, "Another mapper is already defined" if @_mapper
      @_mapper = blk
    end

    def errors
      @_errors ||= {}
    end

    def report_error(name, msg, idx)
      @_on_error.call if @_on_error

      if idx
        messages = (errors[name] ||= [])
        messages[idx] = msg
      else
        errors[name] = msg
      end
    end
    
    def valid?
      errors.empty?
    end

    def has_errors?
      !valid?
    end

    def _unique(name)
      seen = (@_seen ||= Set.new)
      if seen.include?(name)
        raise ArgumentError, "duplicate field: #{name.inspect}"
      else
        seen << name
      end
    end

    def field(name)
      _unique(name)
      value = _field(name)
      fields[name] = field_class.new(self, name, value)
    end

    def group(*field_names)
      field_names.flatten!
      name = field_names.first

      values = field_names.map { |name| fields[name].value }
      field_class.new(self, name, values, true)
    end

    def fieldset(name)
      _unique(name)
      values = _fieldset(name)
      fields[name] = field_class.new(self, name, values, true)
    end

    def form(name, klass = self.class)
      _unique(name)
      input = _form(name)
      form = _build_form(name, input, klass)
      forms[name] = form
    end

    def _build_form(name, input, klass, idx = nil)
      form = klass.new(input)
      form._on_error = proc do
        report_error(name, form.errors, idx)
      end
      form
    end

    def formset(name, klass = self.class)
      _unique(name)
      values = _formset(name)

      idx = -1
      forms = values.map do |input|
        idx += 1
        _build_form(name, input, klass, idx)
      end

      formsets[name] = field_class.new(self, name, forms, true)
    end

    def _field(name)
      input[name]
    end

    def _fieldset(name)
      Array(input[name])
    end

    def _form(name)
      input[name]
    end

    def _formset(name)
      Array(input[name])
    end

    class Field
      attr_reader :value, :name, :form

      def initialize(form, name, value, multiple = false)
        @form = form
        @name = name
        @value = value
        @multiple = multiple
        @ignored = false
      end

      def multiple?
        @multiple
      end

      def ignored?
        @ignored
      end

      def as(name)
        @name = name
        self
      end

      def ignore
        @ignored = true
        self
      end

      def map(&blk)
        return self unless valid?
        if @multiple
          @value.map!(&blk)
        else
          @value = yield(@value)
        end
        self
      end

      def each(&blk)
        return self unless valid?
        if @multiple
          @value.each(&blk)
        else
          yield(@value)
        end
        self
      end

      def valid?
        !@form.errors.has_key?(name)
      end

      def report_error(msg, idx = nil)
        msg = msg.call if msg.respond_to?(:call)
        @form.report_error(name, msg, idx)
      end

      def validate(msg, &blk)
        return self unless valid?

        if !@multiple
          is_valid = yield(value)
          report_error(msg) if !is_valid
          return self
        end

        value.each_with_index do |value, idx|
          is_valid = yield(value)
          report_error(msg, idx) if !is_valid
        end
        self
      end

      def validate_set(msg)
        raise ArgumentError, "#{name} field is not a set" unless @multiple
        return self unless valid?

        is_valid = yield(value)
        report_error(msg) if !is_valid
        self
      end
    end

    define_validation :required do |value|
      value and (!value.respond_to?(:empty?) || !value.empty?)
    end

    define_validation :length do |value, min, max|
      (!min || value.length >= min) and
      (!max || value.length <= max)
    end

    ANCHORED_MATCH = Hash.new do |h, k|
      h[k] = /\A#{k}\z/
    end

    define_validation :regexp do |value, re|
      value =~ ANCHORED_MATCH[re]
    end

    define_validation :match do |value, match|
      match === value
    end

    define_set_validation :count do |values, min, max|
      (!min || values.length >= min) and
      (!max || values.length <= max)
    end

    define_helper :confirmation do |field, &blk|
      confirmation = field.value
      validate(blk || [:confirmation]) do |value|
        !confirmation || confirmation == value
      end
      self
    end
  end
end

