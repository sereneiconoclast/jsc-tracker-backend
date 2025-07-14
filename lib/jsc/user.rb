require 'set'
require 'dynamo_object'
require_relative '../application_config'
require 'httparty'

# From https://openid.net/specs/openid-connect-core-1_0.html#StandardClaims
#
# Subject - Identifier for the End-User at the Issuer

module Jsc
  class User < DynamoObject
    # See https://developers.google.com/identity/protocols/oauth2/native-app
    # and https://console.cloud.google.com/apis/credentials?project=infinitequack-bl-1687379300799
    # TODO: Update

    MAX_LOGINS_TO_TRACK = 6

    field(:sub, id: true) # string containing digits
    field(:name) { 'Tyl Pherry' }
    field(:given_name) { 'Tyl' }
    field(:family_name) { 'Pherry' }
    field(:picture) { 'https://lh3.googleusercontent.com/a/...' }
    field(:email) { 'me@here.com' }
    # Open your Slack profile, click three dots, then "Copy link to profile"
    field(:slack_profile) { 'Slack profile URL' }
    field(:twopager) { 'Two-pager URL' }
    field(:cmf) { 'Candidate-Market Fit goes here' }
    field(:contact_info) { 'Contact Info goes here' }
    field(:jsc, to_json: ->(v) { v == '-1' ? nil : v }) { '-1' }
    # Array<String> - ordered list of contact IDs, most recent first
    field(:contact_id_list, field_class: DbFields::IdListField) { [] }
    # Array<String> - ordered list of archived contact IDs
    field(:archived_contact_id_list, field_class: DbFields::IdListField) { [] }
    # String
    field(:next_contact_id) { 'c0000' }
    # Array<String> - user roles (e.g., ["admin"])
    field(:roles) { [] }
    # The Google login is good until this time
    field(:login_expires_at, field_class: DbFields::TimestampField) { nil }
    # Record the time of last login
    field(:last_logins_at, to_json: ->(v) { v == ['0'] ? [] : v }) { ['0'] }

    alias_method :user_id, :sub

    DEFAULTED_FROM_ACCESS_TOKEN = %i(
      sub
      name
      given_name
      family_name
      picture
      email
    )

    # :sub is excluded because it is the primary key
    ALLOWED_IN_USER_POST = DEFAULTED_FROM_ACCESS_TOKEN + %i(
      slack_profile
      twopager
      cmf
      contact_info
    ) - [:sub]

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

    def admin?
      # Check if user has "admin" role
      self.roles.include?("admin") && $g.admin?(self)
    end

    def grant_admin!
      # Add "admin" role to user's roles list
      self.roles = (self.roles + ["admin"]).uniq
      write!

      # Also update the global admins list
      $g.grant_admin!(self)
    end

    def revoke_admin!
      # Remove "admin" role from user's roles list
      self.roles = self.roles - ["admin"]
      write!

      # Also update the global admins list
      $g.revoke_admin!(self)
    end

    def add_contact
      contact_id = self.next_contact_id
      self.next_contact_id = contact_id.succ
      prepend_id_to_field(:contact_id_list, contact_id)
      c = Contact.new(sub: self.sub, contact_id: contact_id)
      c.write!
      write!
      c
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

    def picture_data
      return nil unless picture
      response = HTTParty.get(picture)
      return nil unless response.success?
      Base64.strict_encode64(response.body)
    end

    def to_json_hash
      super.merge('picture_data' => picture_data)
    end
  end
end
