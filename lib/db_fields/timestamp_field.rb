require 'db_fields/field'

module DbFields
  class TimestampField < Field
    # Returns a Time or nil
    # Store '0' to mean nil
    def from_dynamodb(dval)
      i_val = dval.to_i
      i_val < 1 ? nil : Time.at(i_val)
    end

    # Expects a Time, produces an integer String
    def to_dynamodb(val)
      val ? val.to_i.to_s : '0'
    end

    def to_json_value(val)
      i_val = val.to_i
      i_val < 1 ? nil : i_val
    end
  end
end
