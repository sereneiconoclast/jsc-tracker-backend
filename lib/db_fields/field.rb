module DbFields
  class Field
    def initialize(
      owner:, name:, to_json: nil, &default_value
    )
      default_value ||= -> { nil }
      @owner, @name, @to_json, @default_value = owner, name, to_json, default_value
      raise "Needs an owner" unless owner
      raise "Needs a name" unless name
    end

    # true for fields we do not store in DynamoDB: ID fields and
    # the pk field
    def metadata?
      false
    end

    def normal?
      !metadata?
    end

    def markdown?
      @markdown
    end

    attr_reader :owner, :name

    def raw_default_value
      @default_value
    end

    def default_value
      @default_value.call
    end

    def define_accessor
      owner.attr_accessor name
    end

    # True for everything except the pk field
    def writable?
      true
    end

    def validate!(obj)
    end

    def from_dynamodb(dval)
      strip_if_string(dval)
    end

    def to_dynamodb(val)
      strip_if_string(val)
    end

    def to_json_hash(val)
      {
        name => to_json_value(val)
      }
    end

    def to_json_value(val)
      return @to_json.call(val) if @to_json
      val
    end

    def strip_if_string(s)
      s.respond_to?(:strip) ? s.strip : s
    end

    # Parse input from the user
    def from_user_input(s)
      s
    end

    # Most elements are rendered as-is
    # We do markdown interpretation here if the field calls for that
    def to_inner_html(val)
      markdown? ? $markdown.render(val) : val
    end

    def to_s
      "#{owner}##{name}"
    end
  end
end
