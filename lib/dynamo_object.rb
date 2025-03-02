require_relative 'db_fields/require_all'

class DynamoObject
  # Subclass must define pk

  def self.inherited base
    pk = DbFields::ReadOnlyField.new(
      owner: base, name: :pk, label: '',
      text_field_class: nil, html_element_type: :span)
    created_at = DbFields::CreatedAtField.new(
      owner: base, name: :created_at, label: '',
      text_field_class: nil, html_element_type: :span
    ) { Time.now }
    [pk, created_at].each(&:define_accessor)
    base.instance_variable_set(:@fields,
      { pk: pk, created_at: created_at }
    )
  end

  def self.[](name)
    @fields[name]
  end

  # name: mandatory
  # field_class: optional, defaults to Field, can be IdField, SetField
  #   depending on other input
  # id: optional, defaults to false; true for the primary key
  #   field of the object
  # label: optional, defaults to name.capitalize, used to render the label
  #   in HTML forms
  def self.field name, field_class: nil, id: nil,
    label: nil, html_element_type: nil, &default_value

    raise "Already defined #{@fields[name]}" if @fields[name]
    label ||= name.capitalize

    field_class ||= case
      when id then DbFields::IdField
      when name.to_s.end_with?('_set') then DbFields::SetField
      else DbFields::Field
    end

    field = field_class.new(
      owner: self,
      name: name,
      label: label,
      &default_value
    )
    field.define_accessor
    @fields[name] = field
  end

  def field(name)
    self.class[name]
  end

  def parse_input(field_name, input)
    field(field_name).from_user_input(input)
  end

  def self.fields(&blk)
    blk ||= ->(_) { true }
    @fields.values.find_all(&blk)
  end

  def fields(&blk)
    self.class.fields(&blk)
  end

  def self.field_names
    @fields.keys
  end

  def field_names
    self.class.field_names
  end

  def initialize(**kwargs)
    unrecognized = kwargs.keys - field_names
    raise "Unrecognized constructor args for #{self.class}: #{unrecognized.join(', ')}" unless unrecognized.empty?
    fields(&:writable?).each do |field|
      new_val = if kwargs.has_key?(field.name)
        kwargs[field.name]
      else
        field.default_value
      end
      public_send("#{field.name}=".to_sym, new_val)
      field.validate!(self)
    end
  end

  def to_dynamodb
    self.created_at = Time.now.to_i
    r = { pk: pk }
    fields(&:normal?).each do |field|
      raw_val = public_send(field.name)
      r[field.name] = field.to_dynamodb(raw_val)
    end

    r
  end

  def self.from_dynamodb(dynamodb_record:, **kwargs)
    id_field_names = fields(&:id?).map(&:name)
    raise "Expected ID fields #{id_field_names} but got #{kwargs.keys}" unless
      id_field_names == kwargs.keys

    writable_fields = fields(&:writable?)
    writable_field_names = writable_fields.map(&:name)
    params = dynamodb_record.select do |k, _v|
      writable_field_names.include?(k)
    end
    writable_fields.each do |field|
      next unless params.has_key?(field.name)
      params[field.name] = field.from_dynamodb(params[field.name])
    end

    params.merge!(kwargs)
    new(**params).tap { |o| o.after_load_hook }
  end

  # Override to do additional setup after load from DynamoDB
  def after_load_hook
  end

  # Build and return an Array<InputField> with the id correctly reflecting
  # the prefix, and the value taken from this object
  def base_input_fields
    self.class.base_input_field_names.map do |field_name|
      field(field_name).to_text_field(self)
    end
  end

  def to_s
    id_fields = fields(&:id?).map do |field|
      "#{field.name}: #{public_send(field.name)}"
    end.join(', ')
    "#{self.class}: #{id_fields}"
  end
end
