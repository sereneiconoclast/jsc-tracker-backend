require 'set'
require 'job_slog/dynamo_object'

module JobSlog
  class User < DynamoObject
    include HtmlRenderer

    field(:user_id, id: true)
    field(:email)
    field(:api_key) { 'Specify your Anthropic API key' }
    field(:resume) { 'Upload your résumé here' }
    field(:preferences) { 'Specify your job preferences here' }
    # Set<String>
    field(:active_company_id_set) { Set.new }
    # Set<String>
    field(:archived_company_id_set) { Set.new }
    # String
    field(:next_company_id) { '1' }
    # Empty if none, or a six-digit string
    field(:nonce) { '' }
    # time in seconds since epoch, as a String
    field(:nonce_expiration) { '' }
    # Empty if none, or a random hex string
    field(:session_id) { '' }
    # time in seconds since epoch, as a String
    field(:session_expiration) { '' }
    # Array<Hash> with keys:
    #   'timestamp' (time in seconds since epoch, as a String, that the nonce was generated)
    #   'ip_address' (contents of HTTP_X_FORWARDED_FOR to track caller's IP address)
    #   'nonce' (six digit nonce that we sent in email)
    #   'succeeded_at' (time in seconds since epoch, as a String, that the login succeeded)
    field(:login_attempts) { [] }

    def self.pk(user_id:)
      "#{user_id}_user"
    end

    def pk
      self.class.pk(user_id: user_id)
    end

    # Create a new User with only the bare minimum data
    def self.create(user_id:, email:)
      new(user_id: user_id, email: email)
    end

    def after_load_hook
      # Ruby note: ''.to_i => 0
      unless nonce.empty?
        self.nonce = self.nonce_expiration = '' if nonce_expiration.to_i < Time.now.to_i
      end
      unless session_id.empty?
        self.session_id = self.session_expiration = '' if session_expiration.to_i < Time.now.to_i
      end
    end

    def failed_login_attempt_count(seconds_ago)
      login_attempts.count do |attempt|
        (
          attempt['timestamp'].to_i > (Time.now.to_i - seconds_ago)
        ) && (
          attempt['succeeded_at'].nil?
        )
      end
    end

    # This must be called after the nonce is generated
    def add_login_attempt(ip_address:, max:)
      login_attempts << { 'timestamp' => Time.now.to_i.to_s, 'ip_address' => ip_address, 'nonce' => nonce }
      login_attempts.shift if login_attempts.size > max
    end

    def mark_login_attempt_succeeded!
      if nonce.empty?
        warn "mark_login_attempt_succeeded called with no nonce set"
        return
      end
      the_attempt = login_attempts.find do |attempt|
        attempt['nonce'] == nonce && attempt['succeeded_at'].nil?
      end
      unless the_attempt
        warn "no login attempt matched nonce #{nonce}"
        return
      end
      the_attempt['succeeded_at'] = Time.now.to_i.to_s
    end

    def valid_nonce?(nonce_value)
      return false if nonce.empty?
      nonce_value == nonce
    end

    def valid_cookie?(cookie_value)
      return false if session_id.empty?
      cookie_value == session_id
    end

    def create_session(id:, valid_seconds:)
      self.session_id = id
      self.session_expiration = (Time.now.to_i + valid_seconds).to_s
      # This must be done before we clear the nonce
      mark_login_attempt_succeeded!
      # Clear the nonce, lest it become a ntwice
      self.nonce = self.nonce_expiration = ''
      # TODO: Mark this latest login attempt successful, and exclude successful logins from the
      # limit of 3 per day
    end

    # Read all the active companies and return the list
    def active_companies(db:)
      @active_companies ||= begin
        active_company_id_set.map do |company_id|
          company_by_id(company_id: company_id, db: db)
        end
      end
    end

    def company_by_id(company_id:, db:)
      db.read_company(user_id: user_id, company_id: company_id).tap { |c| c.user = self }
    end

    # Create a new company with the given name and return it
    # Writes the company and the user to DDB
    def create_company(name:, db:)
      new_company = db.create_company(user_id: user_id, company_id: next_company_id, name: name)
      new_company.user = self
      active_company_id_set << next_company_id
      self.next_company_id = (next_company_id.to_i + 1).to_s
      db.write item: to_dynamodb
      new_company
    end

    def editable_api_key_field
      fold(
        fold_name: 'api_key',
        closed_html: 'Click to show and edit Anthropic API key',
        opened_html: editable(
          edit_form_name: 'api_key',
          post_url: "/user/#{user_id}/api_key",
          data: { text: api_key },
          show_text_erb_filename: 'api-key',
          edit_fields: [
            JobSlog::InputField.new(
              name: 'api_key',
              id: 'input_api_key',
              value: api_key
            )
          ]
        )
      )
    end

    def editable_markdown_field(field_name)
      unless %w(resume preferences).include?(field_name)
        raise "Unknown field name: #{field_name}"
      end
      current_content = public_send(field_name.to_sym)
      box(
        fold(
          fold_name: field_name,
          closed_html: "#{ resume.size } characters, updated #{ Time.my_format(created_at) }",
          opened_html: editable(
            edit_form_name: field_name,
            post_url: "/user/#{user_id}/#{field_name}",
            data: { text: current_content },
            show_text_erb_filename: 'markdown-editable-section',
            edit_fields: [
              JobSlog::TextareaField.new(
                name: field_name,
                id: "textarea_#{field_name}",
                value: current_content
              )
            ]
          )
        )
      )
    end

    def form_to_add_company
      editable(
        edit_form_name: 'add_company',
        post_url: "/user/#{user_id}/company/create",
        edit_button_text: 'Add a new company',
        show_text_erb_filename: 'h4-edit-button-only',
        edit_fields: [
          JobSlog::InputField.new(
            name: 'name',
            id: 'input_add_company_name',
            value: ''
          )
        ]
      )
    end
  end
end
