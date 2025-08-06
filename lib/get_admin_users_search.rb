require_relative './monkey_patches/require_all'
require_relative './model/require_all'

def lambda_handler(event:, context:)
  standard_json_handling(event: event) do |input|
    # Admin check is already handled by standard_json_handling.rb

    # Parse query parameters
    query_params = input.query_params || {}
    email_filter = query_params['email']
    name_filter = query_params['name']
    jsc_filter = query_params['jsc']
    admin_only = query_params['admin_only'] == 'true'

    # Get all users (we'll filter in memory since we have a small dataset)
    all_users = Model::User.all

    # Apply filters
    filtered_users = all_users.select do |user|
      # Email filter (substring match)
      if email_filter && !user.email&.downcase&.include?(email_filter.downcase)
        next false
      end

      # Name filter (substring match on given_name or family_name)
      if name_filter
        name_match = false
        if user.given_name&.downcase&.include?(name_filter.downcase)
          name_match = true
        end
        if user.family_name&.downcase&.include?(name_filter.downcase)
          name_match = true
        end
        next false unless name_match
      end

      # JSC filter
      if jsc_filter
        if jsc_filter == '-1'
          # Unassigned users (no JSC membership)
          next false unless user.jsc.nil? || user.jsc.empty?
        else
          # Specific JSC
          next false unless user.jsc == jsc_filter
        end
      end

      # Admin filter
      if admin_only
        next false unless user.admin?
      end

      true
    end

    # Limit to first 20 results
    limited_users = filtered_users.first(20)

    # Build response
    user_results = limited_users.map do |user|
      {
        sub: user.sub,
        name: [user.given_name, user.family_name].compact.join(' '),
        email: user.email,
        jsc: user.jsc,
        admin: user.admin?
      }
    end

    {
      total_count: filtered_users.length,
      users: user_results
    }
  end
end
