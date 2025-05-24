require_relative 'jsc/require_all'

# GET /user/{user_id}
def lambda_handler(event:, context:)
  standard_json_handling(event: event) do |body:, access_token:|

    user_id = event.dig('pathParameters',  'user_id')

    if user_id == '-'
      user_id = access_token['sub']
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
    users = [user.to_json_hash].compact
    {
      users: users,
      jsc: nil,
      jsc_members: nil
    }
  end
end # lambda_handler
