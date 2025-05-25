require_relative 'db_fields/require_all'

class DynamoObject
  # Subclass must define pk

  class NotFoundError < StandardError
  end

  def self.inherited base
    pk = DbFields::ReadOnlyField.new(
      owner: base, name: :pk)
    created_at = DbFields::TimestampField.new(
      owner: base, name: :created_at
    ) { Time.now }
    modified_at = DbFields::TimestampField.new(
      owner: base, name: :modified_at
    ) { Time.now }
    deactivated_at = DbFields::TimestampField.new(
      owner: base, name: :deactivated_at
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
  #   field(s) of the object, used to calculate #pk
  # to_json: a lambda for converting to JSON form
  def self.field name, field_class: nil, id: nil, to_json: nil, &default_value

    raise "Already defined #{@fields[name]}" if @fields[name]

    field_class ||= case
      when id then DbFields::IdField
      when name.to_s.end_with?('_set') then DbFields::SetField
      else DbFields::Field
    end

    field = field_class.new(
      owner: self,
      name: name,
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

  class << self
    def fields(&blk)
      blk ||= ->(_) { true }
      @fields.values.find_all(&blk)
    end

    def field_names
      @fields.keys
    end

    def id_field_names
      fields { |f| f.is_a?(DbFields::IdField) }.map(&:name)
    end
  end

  %i(fields field_names id_field_names).each do |mth_name|
    define_method(mth_name) do |*args, **kwargs, &blk|
      self.class.send(mth_name, *args, **kwargs, &blk)
    end
  end

  def initialize(**kwargs)
    missing_id_fields = id_field_names - kwargs.keys
    raise "Missing ID fields #{missing_id_fields.join(', ')}" unless missing_id_fields.empty?
    unrecognized = kwargs.keys - field_names
    raise "Unrecognized constructor args for #{self.class}: #{unrecognized.join(', ')}" unless unrecognized.empty?

    self.created_at = Time.now.to_i

    id_field_names.each do |field_name|
      send("initialize_#{field_name}".to_sym, kwargs[field_name])
    end

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

  def update(**kwargs)
    fields(&:writable?).each do |field|
      next unless kwargs.has_key?(field.name)
      new_val = kwargs[field.name]
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

  class << self
    # TODO: If a normal (non-administrator) user tries to access a record
    # to which they shouldn't have visibility, raise DynamoObject::NotFoundError
    # Normal users should be able to read the user records of members of their
    # own JSC
    def from_dynamodb(dynamodb_record:, **kwargs)
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

      params.merge!(fields_from_pk(dynamodb_record[:pk]))

      params.merge!(kwargs)
      new(**params).tap { |o| o.after_load_hook }
    end

    def fields_from_pk(pk)
      {}
    end

    # Raise NotFoundError if block returns nil
    def check_for_nil!(params, ok_if_nil: false)
      result = yield
      return result if ok_if_nil || result
      raise NotFoundError.new("No such #{self}: #{params}")
    end
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
