# Zorm::Form

```ruby
form = Zorm::Form.new(params)

form.field(:username).required.length(3, 30)
conf = form.field(:password_confirmation).required
form.field(:password).required.confirmation(conf)

form.output # => { :username => '...', :password => '...' }
```

Zorm::Form is a simple, but powerful, data validator.

## Usage

With Zorm::Form you first instantiate a form with your input data and
*then* declare the validations. Zorm::Form (and Zorm::Form::Field) is
just a regular Ruby class and you should pass instances around when you
find it necessary. It's intentionally *not* trying to be a "DSL".

```ruby
form = Zorm::Form.new(params)
form.field(:name).required.length(3, 100)
```

`#field` returns an instance of Zorm::Form::Field where you declare your
validations. In the example above the `name` field must be non-null, not
empty and between 3 and 100 characters.

After you've checked validations you can see if the form is `valid?` and
get the filtered output. By using Form's `output` you ensure that only
defined fields are present.

```ruby
if form.has_errors?
  p form.errors
else
  p form.output
end
```

Zorm::Form has intentially a very rudimentary error message system. You
should post-process the error messages to provide proper error messages
to the end user.

```ruby
form = Zorm::Form.new({:name => 'a'})
form.field(:name).required.length(3, 100)

form.valid?        # => false
form.errors[:name] # => [:length, 3, 100]
```

All validation methods accept a custom message as a block.

```ruby
form.field(:name)
  .required
  .length(3, 100) { 'Name must be between 3 and 100 characters' }

form.valid?        # => false
form.errors[:name] # => 'Name must be between 3 and 100 characters'
```

It's possible to coerce values as you validate them, and add more
validations on the coerced values.

```ruby
form.field(:age).required.regexp(/\d+/).map(&:to_i).match(1..100)
form.output[:age] # => Returns an Interger between 1 and 100
```

You can also coerce the final output.

```ruby
form.map { |output| User.new(output) }
form.output # => Returns a User instance
```

It's recommended to subclass Zorm::Form for organizing validations.
Every subclass has its own Zorm::Form::Field subclass that you can
extend with custom validations and helpers.

```ruby
class MyForms < Zorm::Form
  define_validation :email do |value|
    value =~ /@/
  end

  define_helper :integer do
    regexp(/\d+/)
    map(&:to_i)
  end

  def signup
    field(:username).required.length(3, 30)
    field(:email).required.email
    field(:age).required.integer
    self # return self for chaining
  end
end

form = MyForms.new(params).signup
```

All examples below will assume you use subclasses to organize forms.

## Validating fieldsets

A *fieldset* is a field that consists of multiple values, usually
presented as checkboxes to the user. The `#fieldset` method extracts an
Array from the input and returns a Zorm::Form::Field.

```ruby
field = form.fieldset(:categories)
field.multiple? # => true, this field has multiple values
```

You can call regular validations; they will validate *each* value
seperately.

```ruby
# Requires that each value is an integer
# The validation will pass if there's no values
field.required.regexp(/\d+/)
```

Error messages will be reported seprately for each value.

```ruby
# Given this input: { :categories => ['', '1'] }
form.errors[:categories] # => [nil, [:required]]
```

You can use `#count` to validate the number of elements in the set. It's
also possible to write custom validations that validate the set itself
(and not each element).

```ruby
field.count(1, 3) # between 1 and 3 elements
```

You can use `#each` if you need to iterate over the values:

```ruby
field.each { |x| p x }
```

## Validating nested forms

`#form` extracts a Hash from the input and creates a new Form. Errors in
the nested form bubbles up into the parent form.

```ruby
class MyForm < Zorm::Form
  def signup
    f = form(:company)
    f.field(:name).required
  end
end
```

Following the subclass-style it's recommended to declare the
validations on nested form in a seperate method.

```ruby
class MyForm < Zorm::Form
  def signup
    form(:company).company
  end

  def company
    field(:name)
    self
  end
end
```

The nested form will by default use the same class as the main class,
but a specific class can also be used.

```ruby
class MyForm < Zorm::Form
  def signup
    form(:company, CompanyForm).company
  end
end
```

## Validating formsets

`#formset` returns a Zorm::Form::Field containing a set of forms. The
regular validations (`#required`, `#regexp`, e.g.) doesn't make much sense
on a fromset, but you can still use set validations (`#count`) and use
`#each` to declare validations on each form.

```ruby
class MyForm < Zorm::Form
  def signup
    # You need to upload between 1 and 4 pictures
    formset(:pictures).each(&:picture).count(1, 4)
  end

  # This is called for every picture-form
  def picture
    field(:title).required
    field(:url).required
  end
end
```

## Writing custom validations

By subclassing you can write your own validations:

```ruby
class MyForm < Zorm::Form
  define_validation :foo do |value, arg1, arg2|
    # return truthy value if the validation is fine
  end
end

form = MyForm.new(params)

# This will invoke the foo-validation with `arg1 == 1` and `arg2 == 2`
form.field(:name).foo(1, 2)
```

For fieldsets (and formsets) you can define validations for the whole
set:

```ruby
class MyForm < Zorm::Form
  define_set_validation :equal do |values|
    v = values.first
    values.all? { |x| x == v }
  end
end
```

## Custom input format

Zorm::Form uses `#_field`, `#_fieldset`#, `#_form` and `#_formset` for
extracing values from the input. You can override these methods if your
input has a different structure.

## Methods

### .new(input)

Returns a new form object with the given input.

```ruby
form = Zorm::Form.new(:username => "judofyr")
```

### #input

Returns the input given to `.new`.

```ruby
form = Zorm::Form.new(:username => "judofyr")
form.input # => { :username => "judofyr" }
```

### #field(name)

Extracts a value using `#_field` and returns a Zorm::Form::Field.

### #fieldset(name)

Extracts a set of values using `#_fieldset` and returns a
Zorm::Form::Field.

### #form(name, klass = self.class)

Extracts a value using `#_form` and returns a new Zorm::Form using the
given `klass`.

### #formset(name, klass = self.class)

Extracts a set values using `#_formset` and returns a new
Zorm::Form::Field that contains a set of Zorm::Form of the given
`klass`.

### #has_errors?

Returns truthy if the form has errors.

```ruby
form.field(:username).required
# If `username` is missing:
form.has_errors? # => true
```

### #errors

Returns a Hash consisting of the error messages.

```ruby
form.field(:username).required
# If `username` is missing:
form.errors[:username] # => [:required]
```

### #valid?

Returns truthy if the form has no errors.

```ruby
form.field(:username).required
# If `username` was present:
form.valid? # => true
```

### #output

Builds a Hash with the fields specified in the form. If a mapper is defined
(see next section) it will be invoked with this Hash.

```ruby
form = Zorm::Form.new({:id => "1", :username => "judofyr"})
form.field(:username)
form.output # => { :username => "judofyr" }
```

### #map { |output| }

Defines a mapper that's invoked when #output is invoked. Only one mapper is
allowed.

```ruby
form.field(:username)
form.map { |output| User.new(output) }

user = form.output # Returns a User-object
user.username      # Returns the username
```

### #_field(name)

```ruby
def _field(name)
  input[name]
end
```

Internal method used to extract a value for a field.

### #_fieldset(name)

```ruby
def _fieldset(name)
  Array(input[name])
end
```

Internal method used to extract values for a fieldset. This method should
always return an Array.

### #_form(name)

```ruby
def _form(name)
  input[name]
end
```

Internal method used to extract a value for a subform.

### #_formset(name)

```ruby
def _formset(name)
  Array(input[name])
end
```

Internal method used to extract values for a formset. This method should
always return an Array.

### .define_validation(name) { |value, *args| }

### .define_set_validation(name) { |value, *args| }

## Methods on Zorm::Field

### #form

Returns the form connected to the field.

```ruby
field = form.field(:username)
field.form # => form
```

### #name

Returns the name of the field.

```ruby
field = form.field(:username)
field.name # => :username
```

### #multiple?

Returns truthy if the field stores multiple values. In that case,
`#value` will return an Array.

```ruby
field = form.field(:username)
field.multiple? # => false

field = form.field(:categories)
field.multiple? # => true
```

### #value

Returns the value of the field. If `#multiple?` is truthy this will always
return an Array.

```ruby
field = form.field(:name)
field.value # => "Magnus"

field = form.fieldset(:categories)
field.value # => ["1", "2"]
```

### #ignore

Marks the field as ignored, causing it to not be included in the form's
output. Returns `self` for chaing.

```ruby
field = form.field(:name).required.ignore
form.valid? # Requires that `name` is present
form.output # Does not include `name`
```

### #ignored?

Returns truthy if the field is ignored.

```ruby
field = form.field(:name)
field.ignored? # => false
field.ignore
field.ignored? # => true
```

### #as(name)

Renames the field.

```ruby
field = form.field(:userName).as(:username)
form.output # => { :username => '...' }
```

### #map { |value| }

Does nothing if the field is already invalid.

Invokes the block with the value of the field.

```ruby
form.field(:age).regexp(/\d+/).map(&:to_i).match(1..100)
```

### #each { |value| }

Does nothing if the field is already invalid.

Invokes the block with the value of the field. If the field stores
multiple values it invokes the block with each element of the Array.

```ruby
form.field(:username).each { |x| p x }
# Prints the username

form.fieldset(:categories).each { |x| p x }
# Prints the values of `categories`
```

### #valid?

Returns truthy if the field is (currently) valid.

```ruby
field = form.field(:username)
field.required # Assume that `username` was not present
field.valid?   # => false
```

### #validate(message) { |value| }

Does nothing if the field is already invalid.

Invokes the block with each value in the field. The block must return
truthy for all values, or an error is reported and the field is marked
invalid.

### #validate_set(message) { |value| }

Raises ArgumentError unless the field containts multiple values.

Does nothing if the field is already invalid.

Invokes the block with an Array of values. The block must return truthy
or an error is reported and the field is marked invalid.

## Built-in validations

### #required

Requires the value to be truthy. If it responds to `#empty?`, that
method must also return falsy.

### #length(min, max)

Requires that the value's `#length` is greater or equal than `min` (if
given) and lesser or equal than `max` (if given).

Be aware that `length(3)` means "at least 3 characters" while `length(3,
3)` is "exactly 3 characters.

### #regexp(re)

Adds anchors to the regexp and requires that it matches the value. Use
`#match` if you want a partial regexp.

### #match(obj)

Requires that `obj === value` returns truthy.

### #confirmation(field)

If `field` has a truthy value, it requires that it's equal to this
field's value.

### #count(min, max)

Requires that the set contains at least `min` elements (if given) and at
most `max` elements (if given).

