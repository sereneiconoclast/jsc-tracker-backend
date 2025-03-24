require_relative 'jsc/require_all'

# GET /user/{user_id}
def lambda_handler(event:, context:)
  user = Jsc::User.read(email: event.dig('pathParameters', 'user_id'))
  users = [user&.to_json_hash].compact
  {
    statusCode: 200,
    body: JSON.generate({
      users: users,
      jsc: nil,
      jsc_members: nil
    })
  }
rescue DynamoObject::NotFoundError => e
  {
    statusCode: 404,
    body: JSON.generate({ error: e.message })
  }
rescue StandardError => e
  {
    statusCode: 500,
    body: JSON.generate({ error: e.message })
  }
end # lambda_handler
