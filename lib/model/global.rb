require 'db'

# Defines $g as Model::Global.instance
module Model
  class Global
    ADMINS_PK = -'$admins'
    ADMINS_USER_IDS_KEY = :user_id_list
    NEXT_JSC_PK = -'$next_jsc'
    NEXT_JSC_KEY = :next_jsc_id

    class << self
      def instance
        @instance ||= new
      end
    end
    $g = instance

    # Read the admin user IDs directly from DynamoDB, return as Array<String>
    def admin_user_ids
      record = db.read(pk: ADMINS_PK) || {}
      record[ADMINS_USER_IDS_KEY] || []
    end

    # Load each User and return an Array<User>
    def admin_users
      admin_user_ids.filter_map do |user_id|
        User.read(sub: user_id, ok_if_missing: true)
      end
    end

    # Check if the given sub is in the admin list
    def admin_id?(sub)
      admin_user_ids.include?(sub)
    end

    # Check if the given User is an admin
    def admin?(user)
      admin_id?(user.sub)
    end

    # Read current list, add user to front if not already there, then write back
    def grant_admin!(user)
      current_list = admin_user_ids
      return if current_list.include?(user.sub)

      new_list = [user.sub] + current_list
      write_admin_user_ids(new_list)
    end

    # Read current list, remove user if present, write back
    def revoke_admin!(user)
      current_list = admin_user_ids
      return unless current_list.include?(user.sub)

      new_list = current_list - [user.sub]
      write_admin_user_ids(new_list)
    end

    # Read the next JSC ID directly from DynamoDB, return as Integer
    def next_jsc
      record = db.read(pk: NEXT_JSC_PK) || {}
      record[NEXT_JSC_KEY]&.to_i || 1
    end

    # Increment the next JSC ID and write it back to DynamoDB
    def increment_next_jsc!
      current_id = next_jsc
      new_id = current_id + 1
      write_next_jsc(new_id)
      current_id  # Return the ID that was used (before increment)
    end

    private

    def write_admin_user_ids(admin_user_ids)
      record = { pk: ADMINS_PK, ADMINS_USER_IDS_KEY => admin_user_ids }
      db.write(item: record)
    end

    def write_next_jsc(next_jsc_id)
      record = { pk: NEXT_JSC_PK, NEXT_JSC_KEY => next_jsc_id.to_s }
      db.write(item: record)
    end
  end
end
