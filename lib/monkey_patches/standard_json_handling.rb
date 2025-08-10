require 'json'
require 'dynamo_object'
require 'active_support/core_ext/hash/keys' # symbolize_keys
require 'standard_json_handler_input'

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
  # create_current_user: lambda accepting an access_token and
  # returning a newly created User
  def standard_json_handling(event:, create_current_user: nil)
    create_current_user ||= ->(_) { raise AuthenticationFailedError }

    query_params = event.dig('queryStringParameters')&.dup || {}
    access_token_str = query_params.delete('access_token')
    raise AuthenticationFailedError unless access_token_str
    access_token = access_token_str.parse_google_access_token
    sub = access_token[:sub]

    origin = event.dig('headers', 'origin')
    unless JSC_CORS_ALLOWED_ORIGINS.include?(origin)
      return({
        statusCode: 404,
        body: JSON.generate({ error: "Not found" })
      })
    end
    response_headers = JSC_CORS_HEADERS.dup
    response_headers['Access-Control-Allow-Origin'] = origin

    current_user =
      Model::User.read(sub: sub, ok_if_missing: true) ||
      create_current_user.call(access_token)

    if (user_id = event.dig('pathParameters', 'user_id'))
      user = if ['-', sub].include?(user_id)
        current_user
      else
        # TODO: Permission check -- OK if authenticated as admin, or
        # selected user is in same JSC as authenticated user
        # TODO: Consider if we ever want to allow certain operations by
        # another user, such as creating/modifying a contact belonging
        # to someone else
        Model::User.read(sub: user_id)
      end
    end

    # Check if this is an admin endpoint and verify admin status
    path = event.dig('path') || ''
    if path.include?('/admin/')
      raise AuthenticationFailedError, "Admin access required" unless current_user.admin?
    end

    body = JSON.parse(event['body'] || '{}').symbolize_keys

    input = StandardJsonHandlerInput.new(
      body: body,
      access_token: access_token,
      query_params: query_params,
      origin: origin,
      current_user: current_user,
      user: user
    )
    result_hash = yield(input)

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
