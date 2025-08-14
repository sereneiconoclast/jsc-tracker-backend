require_relative './monkey_patches/require_all'
require_relative './model/require_all'

# POST /admin/users/revoke_admin
# Revokes admin privileges from a user
def lambda_handler(event:, context:)
  standard_json_handling(event: event) do |input|
    # Admin check is already handled by standard_json_handling.rb

    # Parse request body
    body = input.body
    user_sub = body[:user_sub]

    # Validate input
    raise "user_sub is required" unless user_sub

    # Load the target user
    user = Model::User.read(sub: user_sub)
    raise "User #{user_sub} not found" unless user

    # Check if user is not an admin
    unless user.admin?
      return {
        message: "User #{user_sub} is not an admin",
        user_sub: user_sub,
        already_not_admin: true
      }
    end

    # Revoke admin privileges
    user.revoke_admin!

    # Return success response
    {
      message: "Successfully revoked admin privileges from user #{user_sub}",
      user_sub: user_sub,
      user_name: user.name,
      user_email: user.email
    }
  end
end # lambda_handler
