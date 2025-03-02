require 'active_support/core_ext/hash/keys' # symbolize_keys
require 'aws-sdk-dynamodb'

  class DB
    DEBUG = false

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
        puts("DynamoDB read #{pk} => #{item ? JSON.pretty_generate(item) : 'Not found'}") if DEBUG
      end&.symbolize_keys
    end

    def write item:
      item = item.merge(created_at: Time.now.to_i)
      puts "DynamoDB write #{JSON.pretty_generate(item)}" if DEBUG
      raise "Oops: no pk" unless item[:pk]
      dynamodb.put_item(
        table_name: table_name,
        item: item
      )
    rescue Aws::DynamoDB::Errors::ServiceError => error
      warn "Unable to update DynamoDB: #{error}"
      raise
    end

    def delete pk:
      dynamodb.delete_item({ table_name: table_name, key: { pk: pk }})
      puts "DynamoDB delete #{pk}"
    rescue Aws::DynamoDB::Errors::ServiceError => error
      warn "Unable to update DynamoDB: #{error}"
      raise
    end
  end
