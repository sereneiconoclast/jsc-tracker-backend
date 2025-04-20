require 'json'
require 'dynamo_object'

module ::Kernel
  def standard_json_handling(event:)
    body = JSON.parse(event['body'])
    result_hash = yield(body: body)
    {
      statusCode: 200,
      body: JSON.generate(result_hash)
    }
  rescue DynamoObject::NotFoundError => e
    {
      statusCode: 404,
      body: JSON.generate({ error: e.message })
    }
  rescue JSON::ParserError, StandardError => e
    {
      statusCode: 500,
      body: JSON.generate({ error: e.message })
    }
  end
end