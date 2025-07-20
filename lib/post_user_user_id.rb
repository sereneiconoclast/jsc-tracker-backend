require_relative 'jsc/require_all'
require 'json'

# POST /user/{user_id}
def lambda_handler(event:, context:)
  standard_json_handling(event: event) do |input|
    input.body.keep_if do |k, _v|
      Jsc::User::ALLOWED_IN_USER_POST.include?(k)
    end

    input.user.update(**input.body)
    input.user.write!

    # Return the portion we accepted
    input.body
  end
end # lambda_handler
