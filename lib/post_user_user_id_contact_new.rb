require_relative 'model/require_all'
require 'json'

# POST /user/{user_id}/contact/new
def lambda_handler(event:, context:)
  standard_json_handling(event: event) do |input|
    # TODO: Consider if we ever want to allow creating a contact belonging
    # to someone else
    # Create new contact using the user's add_contact method
    contact = input.user.add_contact

    # Return the new contact in the response
    {
      contact: contact.to_json_hash
    }
  end
end # lambda_handler
