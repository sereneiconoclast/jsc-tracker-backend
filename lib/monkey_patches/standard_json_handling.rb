require 'json'
require 'dynamo_object'

module ::Kernel
  JSC_CORS_ALLOWED_ORIGINS = %w(
    https://static.infinitequack.net
    http://localhost:3000
  )
  JSC_CORS_HEADERS = {
    "Access-Control-Allow-Origin" => nil,
    "Access-Control-Allow-Headers" => "'Content-Type,Authorization,X-Amz-Date,X-Api-Key,X-Amz-Security-Token'",
    "Access-Control-Allow-Methods" => "'GET,POST,PUT,DELETE,OPTIONS'",
    "Access-Control-Max-Age" => "'600'",
  }

  def standard_json_handling(event:)
    origin = event.dig('headers', 'origin')
    unless JSC_CORS_ALLOWED_ORIGINS.include?(origin)
      return({
        statusCode: 404,
        body: JSON.generate({ error: "Not found" })
      })
    end
    response_headers = JSC_CORS_HEADERS.dup
    response_headers['Access-Control-Allow-Origin'] = origin

    body = JSON.parse(event['body'] || '{}')
    result_hash = yield(body: body)
    {
      statusCode: 200,
      headers: response_headers,
      body: JSON.generate(result_hash)
    }
  rescue DynamoObject::NotFoundError => e
    {
      statusCode: 404,
      headers: response_headers,
      body: JSON.generate({ error: e.message, backtrace: e.backtrace })
    }
  rescue JSON::ParserError, StandardError => e
    {
      statusCode: 500,
      headers: response_headers,
      body: JSON.generate({ error: e.message, backtrace: e.backtrace })
    }
  end
end
