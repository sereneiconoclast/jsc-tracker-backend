require_relative 'model/require_all'
require 'json'

# POST /user/{user_id}/contact/{contact_id}
#
# Test from Lambda console:
# {
#   "pathParameters": {
#     "user_id": "115610831205855378140",
#     "contact_id": "c0000"
#   },
#   "queryStringParameters": {
#     "access_token": "ya29.......0178"
#   },
#   "headers": {
#     "origin": "http://localhost:3000"
#   },
#   "body": "{\"notes\": \"https://......./\"}"
# }
#
# The access_token can be found in the Chrome developer console: first log into
# the application, then hit F12, go to the Application tab and find the 'auth'
# cookie and copy the value of "access_token"
#
# Test from curl:
# curl -X POST -v -H "Origin: http://localhost:3000" \
#   --json '{"notes": "http://www.yahoo.com/"}' \
#   'https://jsc-tracker.infinitequack.net/user/115610831205855378140/contact/c0000?access_token=ya29....0178'
def lambda_handler(event:, context:)
  standard_json_handling(event: event) do |input|
    # TODO: Consider if we ever want to allow creating a contact belonging
    # to someone else
    contact_id = event.dig('pathParameters', 'contact_id')
    contact = Model::Contact.read(sub: input.user.sub, contact_id: contact_id)

    # Filter body to only allow permitted fields
    input.body.keep_if do |k, _v|
      Model::Contact::ALLOWED_IN_CONTACT_POST.include?(k)
    end

    # Update the contact
    contact.update(**input.body)
    contact.write!

    # Move the contact to the front of the user's contact list
    input.user.prepend_id_to_field(:contact_id_list, contact_id)
    input.user.write!

    # Return the portion we accepted
    input.body
  end
end # lambda_handler
