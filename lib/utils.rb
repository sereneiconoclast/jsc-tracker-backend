require 'aws-sdk-dynamodb'
require 'jwt'
require 'digest/sha1'

module Utils
  DYNAMO_DB = Aws::DynamoDB::Client.new(region: JSC_REGION)
  TABLE_NAME = 'JSC-Tracker'

  def verify_jwt(token)
    # Implement JWT verification logic here
    # Return the decoded payload or raise an exception if invalid
  end

  def email_to_sha1(email)
    Digest::SHA1.hexdigest(email.downcase)
  end

  def get_user(emailsha1)
    resp = DYNAMO_DB.get_item({
      table_name: TABLE_NAME,
      key: {
        'pk' => "#{emailsha1}-user"
      }
    })
    resp.item
  end

  def update_user(emailsha1, updates)
    DYNAMO_DB.update_item({
      table_name: TABLE_NAME,
      key: { 'pk' => "#{emailsha1}-user" },
      update_expression: updates[:update_expression],
      expression_attribute_values: updates[:expression_attribute_values],
      expression_attribute_names: updates[:expression_attribute_names]
    })
  end
end
