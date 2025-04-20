require_relative 'jsc/require_all'
require 'json'

# POST /user/{user_id}
def lambda_handler(event:, context:)
  standard_json_handling(event: event) do |body|
    user = Jsc::User.read(email: event.dig('pathParameters', 'user_id'))

    body.keep_if do |k, _v|
      ALLOWED_IN_USER_USER_ID_POST.include?(k)
    end

    # TODO: Write these fields into the user, then
    # update DynamoDB

    # Return the portion we accepted
    body
  end
end # lambda_handler
