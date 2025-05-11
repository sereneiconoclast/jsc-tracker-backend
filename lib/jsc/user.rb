require 'securerandom'
require 'set'
require 'dynamo_object'
require_relative '../application_config'

# See if we can index this by 'sub', a mandatory, unique ID assigned to
# every Cognito user.
# From https://openid.net/specs/openid-connect-core-1_0.html#StandardClaims
#
# Subject - Identifier for the End-User at the Issuer
#
# This would allow support for changing email address
# without breaking the connection to the database.
#
# See if it's possible to pull the following fields from Cognito:
# given_name (generally, first name)
# family_name (generally, last name)

module Jsc
  class User < DynamoObject
    # See https://developers.google.com/identity/protocols/oauth2/native-app
    # and https://console.cloud.google.com/apis/credentials?project=infinitequack-bl-1687379300799
    # TODO: Update

    MAX_LOGINS_TO_TRACK = 6

    field(:sub, id: true) # string containing digits
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
    # The Google login is good until this time
    field(:login_expires_at, field_class: DbFields::TimestampField) { nil }
    # Record the time of last login
    field(:last_logins_at, to_json: ->(v) { v == ['0'] ? [] : v }) { ['0'] }

    # :email is excluded because it is the primary key
    # Changing email will need to be done by copying the record
    ALLOWED_IN_USER_USER_ID_POST = %i(
      name
      slack_profile
      twopager
      cmf
    )

    alias_method :user_id, :sub

    class << self
      def pk(sub:)
        "#{sub}_user"
      end

      def fields_from_pk(pk)
        # Remove '_user' suffix
        { sub: pk[0..-6] }
      end

      # If no such user exists with that sub:
      #   - Return nil if ok_if_missing is true.
      #   - Raise NotFoundError if ok_if_missing is false.
      def read(sub:, ok_if_missing: false)
        check_for_nil!("sub: #{sub}", ok_if_nil: ok_if_missing) do
          from_dynamodb(dynamodb_record: db.read(pk: pk(sub: sub)))
        end
      end
    end

    def pk
      @pk ||= self.class.pk(sub: sub)
    end

    def after_load_hook
      # This may not be needed since Google will expire access tokens
      super
    end

    def mark_login_attempt_succeeded!
      # TODO: Does this functionality make sense when Google is
      # authenticating? How about this: Subtract an hour from the access_token
      # expiration time, and that's the login time. If that matches the time of
      # the last login, do nothing. If it's newer then record a new successful
      # login.
    end

    def to_s
      "#{super} (#{email})"
    end
  end
end
