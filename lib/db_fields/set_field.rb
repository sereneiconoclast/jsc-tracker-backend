require 'set'
require 'job_slog/field'

module DbFields
  class SetField < Field
    # DynamoDB doesn't support empty sets! Weird limitation
    # https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/HowItWorks.NamingRulesDataTypes.html

    def from_dynamodb(dval)
      return [].to_set if dval.size == 1 && dval.include?('0')
      dval
    end

    def to_dynamodb(val)
      val.empty? ? ['0'].to_set : val
    end

    def to_json_value(val)
      val.to_a
    end
  end
end
