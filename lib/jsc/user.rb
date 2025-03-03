require 'securerandom'
require 'set'
require 'dynamo_object'
require_relative '../application_config'

module Jsc
  class User < DynamoObject
    # See https://developers.google.com/identity/protocols/oauth2/native-app
    # and https://console.cloud.google.com/apis/credentials?project=infinitequack-bl-1687379300799
    # TODO: Update

    GOOGLE_CLIENT_ID = 'history-eraser-button'
    GOOGLE_CLIENT_SECRET = 'history-eraser-button'

    # From browser's perspective it is port 443 on the CloudFront public-facing side
    GOOGLE_OAUTH_REDIRECT_URI = "https://#{CNAME_FQDN}/oauth2callback"
    GOOGLE_OAUTH_ENDPOINT = 'https://accounts.google.com/o/oauth2/v2/auth'
    GOOGLE_TOKEN_ENDPOINT = "https://www.googleapis.com/oauth2/v4/token"
    GOOGLE_CODE_VERIFIER_CHARS = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~'
    GOOGLE_RAND_CODE_VERIFIER_CHAR = ->(_) { GOOGLE_CODE_VERIFIER_CHARS[rand(GOOGLE_CODE_VERIFIER_CHARS.size)] }
    GOOGLE_RAND_CODE_VERIFIER_SIZE = 60

    MAX_LOGINS_TO_TRACK = 6

    field(:name) { 'Tyl Pherry' }
    field(:email) { 'me@here.com' }
    # Open your Slack profile, click three dots, then "Copy link to profile"
    field(:slack_profile) { 'Slack profile URL' }
    field(:twopager) { 'Two-pager URL' }
    field(:cmf) { 'Candidate-Market Fit goes here' }
    field(:contact_info) { 'Contact Info goes here' }
    field(:jsc, to_json: ->(v) { v == '-1' ? nil : v }) { '-1' }
    # Set<String>
    field(:contact_id_set) { Set.new }
    # Set<String>
    field(:archived_contact_id_set) { Set.new }
    # String
    field(:next_contact_id) { 'c0001' }
    # Random 16-digit hex string
    field(:google_state) { '' }
    # Random 60-character string
    field(:code_verifier) { '' }
    # The Google login is good until this time
    field(:login_expires_at, field_class: DbFields::TimestampField) { nil }
    # Record the time of last login
    field(:last_logins_at, to_json: ->(v) { v == ['0'] ? [] : v }) { ['0'] }

    # Generated during login-challenge process, saved to database for confirmation
    def self.google_generate_state
      SecureRandom.hex(16)
    end

    # Generated during login-challenge process, saved to database for confirmation
    def self.google_generate_code_verifier
      (1..GOOGLE_RAND_CODE_VERIFIER_SIZE).map(&GOOGLE_RAND_CODE_VERIFIER_CHAR).join('')
    end

    def self.pk(email:)
      "#{email.email_to_sha1}_user"
    end

    # This utter reliance on the email address means a user cannot change their email address.
    # We can work around that, when it becomes an issue, by simply copying one user to create
    # another with the new address.
    def pk
      @pk ||= self.class.pk(email: email)
    end

    def user_id
      email.downcase.email_to_sha1
    end

    def self.read(email:)
      from_dynamodb(dynamodb_record: db.read(pk: pk(email: email)))
    end

    def after_load_hook
      # Ruby note: ''.to_i => 0
      if login_expires_at && !(google_state.empty? && code_verifier.empty?)
        self.google_state = self.code_verifier = '' if login_expires_at.to_i < Time.now.to_i
      end
    end

    def mark_login_attempt_succeeded!
      if last_logins_at.size == 1 && last_logins_at.first == '0'
        self.last_logins_at = []
      end
      last_logins_at << Time.now.to_i.to_s
      self.last_logins_at = last_logins_at[(-MAX_LOGINS_TO_TRACK)..-1] if last_logins_at.size > MAX_LOGINS_TO_TRACK
    end

    def to_s
      "#{super} (#{email})"
    end
  end
end
