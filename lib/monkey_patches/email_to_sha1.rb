require_relative '../application_config'
require 'aws-sdk-secretsmanager'

class ::String
  def email_to_sha1
    Digest::SHA1.hexdigest("#{jsc_email_sha1_salt}#{downcase}")
  end
end

module ::Kernel
  def jsc_email_sha1_salt
    $jsc_email_sha1_salt ||= begin
      $secrets_manager_client ||= Aws::SecretsManager::Client.new(region: JSC_REGION)

      # See jsc-tracker-lambda.yaml for the secret ID
      # For a list of exceptions thrown, see
      # https://docs.aws.amazon.com/secretsmanager/latest/apireference/API_GetSecretValue.html
      get_secret_value_response = $secrets_manager_client.
        get_secret_value(secret_id: 'jsc-tracker-email-sha1-salt')

      JSON.parse(get_secret_value_response.secret_string)['email_sha1_salt']
    end
  end
end
