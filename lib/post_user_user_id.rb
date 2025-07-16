require_relative 'jsc/require_all'
require 'json'

# POST /user/{user_id}
def lambda_handler(event:, context:)
  standard_json_handling(event: event) do |body:, access_token:, origin:|
    user_id = event.dig('pathParameters',  'user_id')
    user_id = access_token[:sub] if user_id == '-'

    user = Jsc::User.read(sub: user_id)

    body.keep_if do |k, _v|
      Jsc::User::ALLOWED_IN_USER_POST.include?(k)
    end

    user.update(**body)
    user.write!

    # Return the portion we accepted
    body
  end
end # lambda_handler
