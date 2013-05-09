require 'set'

module Zorm
  class Form
    # A form takes some `input` and stores it.
    def initialize(input)
      @input = input
    end

    attr_accessor :input

    # Form never accesses @input internally, but uses these helper
    # methods to extract data. You can override these in a subclass to
    # support different types of input.
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

    # Every form class as a field class. It defaults to Field.
    def self.field_class
      @field_class || Field
    end

    def field_class
      self.class.field_class
    end

    class << self
      attr_writer :field_class
    end

    # .. and is subclassed when you subclass Form.
    def self.inherited(klass)
      super
      klass.field_class = Class.new(klass.field_class)
    end

    # You can define methods on the field class.
    def self.define_helper(name, &blk)
      field_class.class_eval do
        define_method(name, &blk)
      end
    end

    # Validations are just helpers that call #validate.
    def self.define_validation(name, &blk)
      define_helper(name) do |*args, &msg|
        msg ||= [name, *args]
        validate(msg) do |value|
          instance_exec(value, *args, &blk)
        end
      end
    end

    # Set validations are just helpers that call #validate_set.
    def self.define_set_validation(name, &blk)
      define_helper(name) do |*args, &msg|
        msg ||= [name, *args]
        validate_set(msg) do |value|
          instance_exec(value, *args, &blk)
        end
      end
    end

    # We keep track of every field, form and formsets we're working on.
    # Fieldsets are stored together with fields.

    def fields
      @_fields ||= {}
    end

    def forms
      @_forms ||= {}
    end

    def formsets
      @_formsets ||= {}
    end

    # Output is produced by iterating over every known field(set) and form(set)
    def output
      res = {}
      fields.each do |name, field|
        # Fields can be both renamed and ignored
        res[field.name] = field.value unless field.ignored?
      end
      forms.each do |name, form|
        # Call #output recursively
        res[name] = form.output
      end
      formsets.each do |name, form|
        # Call #output recursively on every form in the set
        res[form.name] = form.value.map(&:output)
      end
      res = @_mapper.call(res) if @_mapper
      res
    end

    # You can define a mapper for the whole form. #output will invoke this.
    def map(&blk)
      raise ArgumentError, "Another mapper is already defined" if @_mapper
      @_mapper = blk
    end

    # Errors are empty by default.
    def errors
      @_errors ||= {}
    end

    # Validations will call #report_error to report an error on a specific field.
    def report_error(name, msg, idx)
      @_on_error.call if @_on_error

      # If idx is given it's an error for a set, and we create an Array
      # in the error-object.
      if idx
        messages = (errors[name] ||= [])
        messages[idx] = msg
      else
        errors[name] = msg
      end
    end

    # We use _on_error internally to propagate errors up to parent forms.
    attr_writer :_on_error
    
    def valid?
      errors.empty?
    end

    def has_errors?
      !valid?
    end

    # We want to ensure that you call #field, #fieldset, #form or
    # #formset multiple times on the same field.
    def _unique(name)
      seen = (@_seen ||= Set.new)
      if seen.include?(name)
        raise ArgumentError, "duplicate field: #{name.inspect}"
      else
        seen << name
      end
    end

    # #field and #fieldset are very similar. The only difference being
    # the getter method they call (_field/_fieldset) and that #fieldset
    # marks the field as containing multiple values.
    def field(name)
      _unique(name)
      value = _field(name)
      fields[name] = field_class.new(self, name, value)
    end

    def fieldset(name)
      _unique(name)
      values = _fieldset(name)
      fields[name] = field_class.new(self, name, values, true) # true => multiple
    end

    # Builds a form that propagates errors up to this form.
    def _build_form(name, input, klass, idx = nil)
      form = klass.new(input)
      form._on_error = proc do
        report_error(name, form.errors, idx)
      end
      form
    end

    # #form and #formset are thus just wrappers around _build_form.
    def form(name, klass = self.class)
      _unique(name)
      input = _form(name)
      form = _build_form(name, input, klass)
      forms[name] = form
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

    # Field represents a field (that may contain multiple values).
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

      # #as renames the field.
      def as(name)
        @name = name
        self
      end

      # #ignore makes Form#output ignore the field
      def ignore
        @ignored = true
        self
      end

      # Field supports a chaining API, we don't want to continue
      # chaining if any of the validations are invalid. We use #valid?
      # (mostly internally) and bail out early in the methods below.
      def valid?
        !@form.errors.has_key?(name)
      end

      # #map changes the internal value(s).
      def map(&blk)
        return self unless valid?
        if @multiple
          @value.map!(&blk)
        else
          @value = yield(@value)
        end
        self
      end

      # #each just yields the internal value(s).
      def each(&blk)
        return self unless valid?
        if @multiple
          @value.each(&blk)
        else
          yield(@value)
        end
        self
      end

      # Reports an error (propagates into Form#report_error).
      def report_error(msg, idx = nil)
        # Support passing in blocks
        msg = msg.call if msg.respond_to?(:call)
        @form.report_error(name, msg, idx)
      end

      def validate(msg, &blk)
        return self unless valid?

        # A single value
        if !@multiple
          is_valid = yield(value)
          report_error(msg) if !is_valid
          return self
        end

        # Multiple values
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

    # Built-in validations.

    define_validation :required do |value|
      value and (!value.respond_to?(:empty?) || !value.empty?)
    end

    define_validation :length do |value, min, max|
      (!min || value.length >= min) and
      (!max || value.length <= max)
    end

    # For #regexp we make sure to always anchor the regexp to match the
    # whole string.
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

