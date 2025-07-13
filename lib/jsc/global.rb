require 'db'

# Defines $g as Jsc::Global.instance
module Jsc
  class Global
    ADMINS_PK = -'$admins'
    ADMINS_USER_IDS_KEY = :user_id_list

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

    private

    def write_admin_user_ids(admin_user_ids)
      record = { pk: ADMINS_PK, ADMINS_USER_IDS_KEY => admin_user_ids }
      db.write(item: record)
    end
  end
end
