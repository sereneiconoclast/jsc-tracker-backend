require_relative 'jsc/require_all'

# Create authenticated user if never seen before
CREATE_CURRENT_USER = lambda do |access_token|
  args = access_token.keep_if do |k, _v|
    Jsc::User::DEFAULTED_FROM_ACCESS_TOKEN.include?(k)
  end
  Jsc::User.new(**args).write!
end

# GET /user/{user_id}
def lambda_handler(event:, context:)
  standard_json_handling(event: event, create_current_user: CREATE_CURRENT_USER) do |input|
    # Load the user's most recent contacts
    # The contact_id_list is already ordered with most recent first, so just take first 20
    # TODO: Allow filtering the list by name, email, whatever
    contacts = input.user.contact_id_list.take(20).
      filter_map do |contact_id|
        Jsc::Contact.read(
          sub: input.user.sub, contact_id: contact_id, ok_if_missing: true
        )&.to_json_hash
      end
    # TODO: When the given contact ID couldn't be found, it should be deleted
    # from contact_id_list

    users = [input.user.to_json_hash].compact

    response_hash = {
      users: users,
      contacts: contacts,
      jsc: nil,
      jsc_members: nil,
    }

    # Add roles information for admin users
    if input.current_user.admin?
      # Calculate admin page URL based on origin
      admin_url = if input.origin == 'http://localhost:3000'
        'http://localhost:3000/JSC-Tracker/roleAdmin'
      else # https://static.infinitequack.net
        'https://static.infinitequack.net/JSC-Tracker/roleAdmin/'
      end

      response_hash[:roles] = {
        admin: admin_url
      }
    end

    response_hash
  end
end # lambda_handler
