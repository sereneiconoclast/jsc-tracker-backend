require_relative 'db_fields/require_all'

class DynamoObject
  # Subclass must define pk

  class NotFoundError < StandardError
  end

  def self.inherited base
    pk = DbFields::ReadOnlyField.new(
      owner: base, name: :pk, label: '')
    created_at = DbFields::TimestampField.new(
      owner: base, name: :created_at, label: 'Created at'
    ) { Time.now }
    modified_at = DbFields::TimestampField.new(
      owner: base, name: :modified_at, label: 'Modified at'
    ) { Time.now }
    deactivated_at = DbFields::TimestampField.new(
      owner: base, name: :deactivated_at, label: 'Deactivated at'
    ) { nil }
    [pk, created_at, modified_at, deactivated_at].each(&:define_accessor)
    base.instance_variable_set(:@fields,
      { pk: pk, created_at: created_at, modified_at: modified_at, deactivated_at: deactivated_at }
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
    label: nil, to_json: nil, &default_value

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
      to_json: to_json,
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
    self.created_at = Time.now.to_i
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
    r = { pk: pk }
    fields(&:normal?).each do |field|
      raw_val = public_send(field.name)
      r[field.name] = field.to_dynamodb(raw_val)
    end

    r
  end

  def ==(other)
    return true if other.equal?(self)
    return false unless other.class.equal?(self.class)
    to_dynamodb == other.to_dynamodb
  end

  def hash
    to_dynamodb.hash
  end

  def write!
    self.modified_at = Time.now
    db.write(item: to_dynamodb)
  end

  # TODO: If a normal (non-administrator) user tries to access a record
  # to which they shouldn't have visibility, raise DynamoObject::NotFoundError
  # Normal users should be able to read the user records of members of their
  # own JSC
  def self.from_dynamodb(dynamodb_record:, **kwargs)
    return nil unless dynamodb_record
    raise "Call this on a subclass" if self == DynamoObject

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

  # Raise NotFoundError if block returns nil
  def self.check_for_nil!(params, ok_if_nil: false)
    result = yield
    return result if ok_if_nil || result
    raise NotFoundError.new("No such #{self}: #{params}")
  end

  # Override to do additional setup after load from DynamoDB
  def after_load_hook
  end

  def active?
    !deactivated_at
  end

  def deactivate!
    self.deactivated_at = Time.now
  end

  def to_json_hash
    fields.map { |f| f.to_json_hash(public_send(f.name)) }.reduce({}, :merge)
  end

  def to_s
    "#{self.class}: #{pk}"
  end
end
