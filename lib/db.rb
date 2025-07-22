require 'active_support/core_ext/hash/keys' # symbolize_keys
require 'aws-sdk-dynamodb'

class DB
  debug_me!

  def initialize(table:, region:)
    @table_name = table
    @region = region
    # In theory we could pass access_key_id: and secret_access_key:
    # For now, we get those from ~/.aws/credentials
    @dynamodb = Aws::DynamoDB::Client.new(region: region)
  end

  attr_reader :dynamodb, :table_name, :region

  def read pk:
    dynamodb.get_item(
      {
        table_name: table_name,
        key: { pk: pk }
      }
    )&.item.tap do |item|
      debug("DynamoDB read #{pk} => #{item ? JSON.pretty_generate(item) : 'Not found'}")
    end&.symbolize_keys
  end

  def write item:
    pk = item[:pk]
    raise "Oops: no pk in #{item.inspect}" unless pk
    debug("DynamoDB write #{JSON.pretty_generate(item)}")
    dynamodb.put_item(
      table_name: table_name,
      item: item
    )
  rescue Aws::DynamoDB::Errors::ServiceError => error
    warn "Unable to write #{pk} to DynamoDB: #{error}"
    raise
  end

  def delete pk:
    dynamodb.delete_item({ table_name: table_name, key: { pk: pk }})
    debug("DynamoDB delete #{pk}")
  rescue Aws::DynamoDB::Errors::ServiceError => error
    warn "Unable to delete #{pk} from DynamoDB: #{error}"
    raise
  end

  # Atomically increment a string counter field for a given pk and field.
  # Stores values as strings, uses .succ for incrementing, and retries on collision.
  # initial_value: value to return if the field did not exist (default 1)
  def atomic_increment(pk:, field:, initial_value: 1)
    resp = dynamodb.get_item(table_name: table_name, key: { pk: pk })
    old_value = resp.item&.dig(field.to_s)

    if old_value
      new_value = old_value.succ
      dynamodb.update_item(
        table_name: table_name,
        key: { pk: pk },
        update_expression: "SET #{field} = :newval",
        condition_expression: "#{field} = :oldval",
        expression_attribute_values: {
          ":newval" => new_value,
          ":oldval" => old_value
        }
      )
      return old_value.to_i
    else
      new_value = initial_value.to_s.succ
      dynamodb.put_item(
        table_name: table_name,
        item: { pk: pk, field => new_value },
        condition_expression: 'attribute_not_exists(pk)'
      )
      return initial_value
    end
  rescue Aws::DynamoDB::Errors::ConditionalCheckFailedException
    retry
  end
end
