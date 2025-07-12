require_relative 'jsc/require_all'
require 'json'

# POST /user/{user_id}/contact/{contact_id}
def lambda_handler(event:, context:)
  standard_json_handling(event: event) do |body:, access_token:|
    user_id = event.dig('pathParameters', 'user_id')
    user_id = access_token[:sub] if user_id == '-'
    contact_id = event.dig('pathParameters', 'contact_id')

    user = Jsc::User.read(sub: user_id)
    contact = Jsc::Contact.read(sub: user_id, contact_id: contact_id)

    # Filter body to only allow permitted fields
    body.keep_if do |k, _v|
      Jsc::Contact::ALLOWED_IN_CONTACT_POST.include?(k)
    end

    # Update the contact
    contact.update(**body)
    contact.write!

    # Return the portion we accepted
    body
  end
end # lambda_handler
