require_relative './monkey_patches/require_all'
require_relative './model/require_all'

def lambda_handler(event:, context:)
  standard_json_handling(event: event) do |input|
    # Admin check is already handled by standard_json_handling.rb

    # Parse query parameters
    query_params = input.query_params
    email_filter = query_params['email']
    name_filter = query_params['name']
    jsc_filter = query_params['jsc']
    admin_only = query_params['admin_only'] == 'true'

    # If JSC filter is specified, start with JSC members for efficiency
    if jsc_filter && jsc_filter != '-1'
      begin
        # Look up the JSC first
        jsc = Model::Jsc.read(jsc_id: jsc_filter.to_i)

        # Get users from this JSC
        candidate_users = jsc.users.compact
      rescue DynamoObject::NotFoundError
        # Return error if JSC doesn't exist
        return {
          error: "No such JSC: #{jsc_filter}",
          total_count: 0,
          users: []
        }
      end
    elsif jsc_filter == '-1'
      # Special case: unassigned users (no JSC membership)
      # We still need to scan all users to find those without JSC
      candidate_users = Model::User.all.select { |user| user.jsc.nil? || user.jsc.empty? }
    else
      # No JSC filter - start with all users
      candidate_users = Model::User.all
    end

    # Apply remaining filters to the candidate users
    filtered_users = candidate_users.select do |user|
      # Email filter (substring match)
      if email_filter && !user.email&.downcase&.include?(email_filter.downcase)
        next false
      end

      # Name filter (substring match)
      if name_filter
        next false unless user.name&.downcase&.include?(name_filter.downcase)
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
        name: user.name,
        email: user.email,
        picture_data: user.picture_data,
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
