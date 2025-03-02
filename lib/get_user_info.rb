require_relative './utils'

class GetUserInfo
  def lambda_handler(event:, context:)
    # Verify JWT and get user email
    jwt_payload = verify_jwt(event['headers']['Authorization'].split(' ').last)
    user_email = jwt_payload['email']
    emailsha1 = email_to_sha1(user_email)

    # Get user information
    user = get_user(emailsha1)

    # Get JSC information if user is in a JSC
    jsc_info = nil
    jsc_members = []
    jsc_no = user['jsc']
    case jsc_no
    when '0', '-1'
      jsc_members << emailsha1
    else
      jsc_resp = DYNAMO_DB.get_item({
        table_name: TABLE_NAME,
        key: { 'pk' => "#{jsc-no}-members" }
      })
      jsc_info = jsc_resp.item
    end

    # Get information for all JSC members
    jsc_info['members'].each do |member_emailsha1|
      jsc_members << get_user(member_emailsha1)
    end

    {
      statusCode: 200,
      body: JSON.generate({
        user: user,
        jsc: jsc_info,
        jsc_members: jsc_members
      })
    }
  rescue StandardError => e
    {
      statusCode: 500,
      body: JSON.generate({ error: e.message })
    }
  end # lambda_handler
end # GetUserInfo

GET_USER_INFO = GetUserInfo.new
def lambda_handler(event:, context:)
  GET_USER_INFO.lambda_handler(event:, context:)
end
