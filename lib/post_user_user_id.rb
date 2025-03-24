require_relative 'jsc/user'

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
rescue StandardError => e
  {
    statusCode: 500,
    body: JSON.generate({ error: e.message })
  }
end # lambda_handler
