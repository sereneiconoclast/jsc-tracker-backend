class StandardJsonHandlerInput
  attr_reader :body, :access_token, :origin, :current_user, :user

  # body - a Hash (parsed JSON input, keys are operation-dependent), symbol keys
  # access_token - a Hash produced by parse_google_access_token
  #  sub: digit string, the user ID assigned by Google
  #  For other keys see Jsc::User::DEFAULTED_FROM_ACCESS_TOKEN
  # origin - a URL; see JSC_CORS_ALLOWED_ORIGINS
  # current_user - a Jsc::User instance for the current logged-in user, or nil
  # user - a Jsc::User instance, usually the same as current_user but may be
  # different if another user's ID was passed
  def initialize(body:, access_token:, origin:, current_user:, user:)
    @body = body
    @access_token = access_token
    @origin = origin
    @current_user = current_user
    @user = user
  end

  def sub
    self.access_token[:sub]
  end
end
