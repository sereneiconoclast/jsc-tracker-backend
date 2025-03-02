require 'job_slog/field'

module DbFields
  class CreatedAtField < Field
    def from_dynamodb(dval)
      dval.to_i
    end

    def to_dynamodb(val)
      val.to_i
    end

    def default_value
      Time.now.to_i
    end
  end
end
