require_relative 'jsc/require_all'

# GET /user/{user_id}
def lambda_handler(event:, context:)
  standard_json_handling(event: event) do |body|
    user = Jsc::User.read(email: event.dig('pathParameters', 'user_id'))
    users = [user&.to_json_hash].compact
    {
      users: users,
      jsc: nil,
      jsc_members: nil
    }
  end
end # lambda_handler
