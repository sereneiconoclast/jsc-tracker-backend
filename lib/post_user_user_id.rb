require_relative 'jsc/require_all'

# POST /user/{user_id}
def lambda_handler(event:, context:)
  # user = Jsc::User.read(email: event.dig('pathParameters', 'user_id'))
  {
    statusCode: 200,
    body: JSON.generate({
      event: event,
      context_class: context.class.instance_methods(false)
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
