require_relative 'model/require_all'
require 'json'

=begin
OPERATION METADATA:
HttpVerb: POST
Path: /user/{user_id}
=end
def lambda_handler(event:, context:)
  standard_json_handling(event: event) do |input|
    input.body.keep_if do |k, _v|
      Model::User::ALLOWED_IN_USER_POST.include?(k)
    end

    input.user.update(**input.body)
    input.user.write!

    # Return the portion we accepted
    input.body
  end
end # lambda_handler
