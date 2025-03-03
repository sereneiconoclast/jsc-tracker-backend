require_relative 'jsc/user'

def lambda_handler(event:, context:)
  user = Jsc::User.read(email: event['email'])
  users = [user&.to_json_hash].compact
  {
    statusCode: 200,
    body: JSON.generate({
      users: users,
      jsc: nil,
      jsc_members: nil
    })
  }
rescue StandardError => e
  {
    statusCode: 500,
    body: JSON.generate({ error: e.message })
  }
end # lambda_handler
