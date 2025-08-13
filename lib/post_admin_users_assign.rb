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
    # Validate JSC number format (should be a positive integer, digits only)
    jsc_number = jsc_number.to_s
    raise "Invalid JSC number: #{jsc_number}" unless jsc_number =~ /^[1-9][0-9]*$/

    modified = Set.new
    load_jsc = Hash.new { |h, k| h[k] = Model::Jsc.read(jsc_id: k) }

    # Load the target JSC
    jsc = load_jsc[jsc_number]
    raise "JSC #{jsc_number} not found" unless jsc

    # Track users that were previously unassigned
    previously_unassigned_users = []

    # Look up all users; if one isn't found, error out before changing anything
    # Drop any that are already in the target JSC
    users = user_subs.map do |user_sub|
      user = Model::User.read(sub: user_sub) or raise "User #{user_sub} not found"
      (user.jsc != jsc_number) ? user : nil
    end.compact

    # Process each user
    users.each do |user|
      # Check if user was previously unassigned
      if user.unassigned?
        previously_unassigned_users << user.sub
      else
        # Remove user from previous JSC
        # Mark as requiring a save
        modified << (load_jsc[user.jsc]&.remove_user(user))
      end

      # Update user's JSC assignment and add user to new JSC
      # Mark as requiring a save
      modified << user.assign_to_jsc(jsc_number)
      modified << jsc.add_user(user)
    end

    # Update the $unassigned global if any users were previously unassigned
    if previously_unassigned_users.any?
      # This would require implementing a global unassigned users tracking system
      # For now, we'll just log it
      puts "Users previously unassigned: #{previously_unassigned_users.join(', ')}"
    end

    modified.delete(nil)
    modified.each(&:write!)

    # Return success response
    {
      message: "Successfully assigned #{users.length} user(s) to JSC #{jsc_number}",
      assigned_users: users.map(&:sub),
      jsc_number: jsc_number,
      previously_unassigned: previously_unassigned_users
    }
  end
end # lambda_handler
