require_relative 'jsc/require_all'
require 'json'

# POST /user/{user_id}/contact/new
def lambda_handler(event:, context:)
  standard_json_handling(event: event) do |body:, access_token:|
    user_id = event.dig('pathParameters',  'user_id')
    user_id = access_token[:sub] if user_id == '-'

    user = Jsc::User.read(sub: user_id)

    # Create new contact using the user's add_contact method
    contact = user.add_contact

    # Return the new contact in the response
    {
      contact: contact.to_json_hash
    }
  end
end # lambda_handler
