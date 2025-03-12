require 'aws-sdk-secretsmanager'
require_relative 'monkey_patches/require_all'

require 'db'

JSC_REGION = 'us-west-2'

# Very important! CloudFront must be configured with behavior:
# * Redirect HTTP to HTTPS
# * Allow all HTTP methods
# * Cache policy: CachingDisabled (otherwise requests will go through with a stale 'google_state')
# * Origin request policy: AllViewer (otherwise query string parameters will not pass through)
# * Turn OFF AWS WAF, or it will block requests from some devices - the Echo Show devices -
#   because the requests are too large and WAF blocks them

CNAME_FQDN = 'jsc.infinitequack.net' # CloudFront CNAME 'abcdefghijklmn.cloudfront.net'

# Use this code snippet in your app.
# If you need more information about configurations or implementing the sample code, visit the AWS docs:
# https://aws.amazon.com/developer/language/ruby/

module ::Kernel
  def jsc_email_sha1_salt
    $jsc_email_sha1_salt ||= begin
      $secrets_manager_client ||= Aws::SecretsManager::Client.new(region: JSC_REGION)

      # See jsc-tracker-lambda.yaml for the secret ID
      # For a list of exceptions thrown, see
      # https://docs.aws.amazon.com/secretsmanager/latest/apireference/API_GetSecretValue.html
      get_secret_value_response = $secrets_manager_client.get_secret_value(secret_id: 'jsc-tracker-email-sha1-salt')

      JSON.parse(get_secret_value_response.secret_string)['email_sha1_salt']
    end
  end

  def db
    $db ||= begin
      DB.new(table: 'JSC-Tracker', region: JSC_REGION)
    end
  end
end

