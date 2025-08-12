require_relative './monkey_patches/require_all'
require_relative './model/require_all'

# POST /admin/users/assign
# Assigns users to a JSC
def lambda_handler(event:, context:)
  standard_json_handling(event: event) do |input|
    # Admin check is already handled by standard_json_handling.rb

    # Parse request body
    body = input.body
    user_subs = body[:user_subs] || []
    jsc_number = body[:jsc_number]

    # Validate input
    raise "user_subs is required and must be an array" unless user_subs.is_a?(Array) && !user_subs.empty?
    raise "jsc_number is required" unless jsc_number

    # Convert jsc_number to string if it's a number
    jsc_number = jsc_number.to_s

    # Validate JSC number format (should not start with 0, and should not be "0" or "-1")
    raise "Invalid JSC number: #{jsc_number}" if jsc_number.start_with?('0') || jsc_number == "0" || jsc_number == "-1"

    # Load the target JSC
    jsc = Model::Jsc.read(jsc_id: jsc_number.to_i)
    raise "JSC #{jsc_number} not found" unless jsc

    # Track users that were previously unassigned
    previously_unassigned_users = []

    # Process each user
    user_subs.each do |user_sub|
      user = Model::User.read(sub: user_sub)
      raise "User #{user_sub} not found" unless user

      # Check if user was previously unassigned
      if user.jsc.nil? || user.jsc.empty? || user.jsc == "-1"
        previously_unassigned_users << user_sub
      else
        # Remove user from previous JSC
        previous_jsc = Model::Jsc.read(jsc_id: user.jsc.to_i)
        if previous_jsc
          previous_jsc.remove_user!(user)
        end
      end

      # Update user's JSC assignment
      user.assign_to_jsc!(jsc_number)

      # Add user to new JSC
      jsc.add_user!(user)
    end

    # Update the $unassigned global if any users were previously unassigned
    if previously_unassigned_users.any?
      # This would require implementing a global unassigned users tracking system
      # For now, we'll just log it
      puts "Users previously unassigned: #{previously_unassigned_users.join(', ')}"
    end

    # Return success response
    {
      message: "Successfully assigned #{user_subs.length} user(s) to JSC #{jsc_number}",
      assigned_users: user_subs,
      jsc_number: jsc_number,
      previously_unassigned: previously_unassigned_users
    }
  end
end # lambda_handler
