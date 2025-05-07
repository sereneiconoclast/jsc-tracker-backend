require 'json'
require 'dynamo_object'

module ::Kernel
  JSC_CORS_HEADERS = {
    "Access-Control-Allow-Origin" => "'https://static.infinitequack.net,http://localhost:3000'",
    "Access-Control-Allow-Headers" => "'Content-Type,Authorization,X-Amz-Date,X-Api-Key,X-Amz-Security-Token'",
    "Access-Control-Allow-Methods" => "'GET,POST,PUT,DELETE,OPTIONS'",
    "Access-Control-Max-Age" => "'600'",
  }

  def standard_json_handling(event:)
    body = JSON.parse(event['body'])
    result_hash = yield(body: body)
    {
      statusCode: 200,
      headers: JSC_CORS_HEADERS,
      body: JSON.generate(result_hash)
    }
  rescue DynamoObject::NotFoundError => e
    {
      statusCode: 404,
      headers: JSC_CORS_HEADERS,
      body: JSON.generate({ error: e.message })
    }
  rescue JSON::ParserError, StandardError => e
    {
      statusCode: 500,
      headers: JSC_CORS_HEADERS,
      body: JSON.generate({ error: e.message })
    }
  end
end