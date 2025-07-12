require_relative 'jsc/require_all'

# GET /user/{user_id}
def lambda_handler(event:, context:)
  standard_json_handling(event: event) do |body:, access_token:|

    user_id = event.dig('pathParameters',  'user_id')

    if user_id == '-'
      user_id = access_token[:sub]
      user = Jsc::User.read(sub: user_id, ok_if_missing: true)
      unless user
        args = access_token.keep_if do |k, _v|
          Jsc::User::DEFAULTED_FROM_ACCESS_TOKEN.include?(k)
        end
        user = Jsc::User.new(**args)
        user.write!
      end
    else
      user = Jsc::User.read(sub: user_id)
    end

    # Load the user's most recent contacts
    # Sort contact IDs in reverse order (most recent first) and take first 20
    contacts = user.contact_id_set.sort { |a, b| b <=> a }.take(20).
      filter_map do |contact_id|
        Jsc::Contact.read(
          sub: user.sub, contact_id: contact_id, ok_if_missing: true
        )&.to_json_hash
      end
    # TODO: When the given contact ID couldn't be found, it should be deleted
    # from contact_id_set

    users = [user.to_json_hash].compact
    {
      users: users,
      contacts: contacts,
      jsc: nil,
      jsc_members: nil,
    }
  end
end # lambda_handler
