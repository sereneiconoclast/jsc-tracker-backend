require 'json'
require 'dynamo_object'
require 'active_support/core_ext/hash/keys' # symbolize_keys

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

  # event:
  # https://docs.aws.amazon.com/apigateway/latest/developerguide/set-up-lambda-proxy-integrations.html#api-gateway-simple-proxy-for-lambda-input-format
  def standard_json_handling(event:)
    access_token_str = event.dig('queryStringParameters', 'access_token')
    raise AuthenticationFailedError unless access_token_str
    access_token = access_token_str.parse_google_access_token

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
    result_hash = yield(body: body.symbolize_keys, access_token: access_token)
    {
      statusCode: 200,
      headers: response_headers,
      body: JSON.generate(result_hash)
    }
  rescue DynamoObject::NotFoundError, AuthenticationFailedError => e
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
