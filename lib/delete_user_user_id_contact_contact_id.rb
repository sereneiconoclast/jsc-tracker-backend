require_relative 'model/require_all'
require 'json'

=begin
OPERATION METADATA:
HttpVerb: DELETE
Path: /user/{user_id}/contact/{contact_id}
=end
def lambda_handler(event:, context:)
  standard_json_handling(event: event) do |input|
    # TODO: Consider if we ever want to allow archiving a contact belonging
    # to someone else
    contact_id = event.dig('pathParameters', 'contact_id')
    # Just to ensure the contact actually exists
    Model::Contact.read(sub: input.user.sub, contact_id: contact_id)

    # Archive the contact (move from contact_id_list to archived_contact_id_list)
    input.user.archive_contact(contact_id)

    # Return the archived contact info
    {
      message: 'Contact archived successfully',
      contact_id: contact_id
    }
  end
end # lambda_handler
