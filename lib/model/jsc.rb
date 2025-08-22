require 'dynamo_object'

module Model
  class Jsc < DynamoObject
    # Primary key: "#{jsc_id}_jsc"
    field(:jsc_id, id: true) # Integer, e.g., 1, 2, 3...

    # Array<String> - ordered list of user subs assigned to this JSC
    field(:members, field_class: DbFields::IdListField) { [] }

    class << self
      def pk(jsc_id:)
        "#{jsc_id}_jsc"
      end

      def fields_from_pk(pk)
        # pk is "#{jsc_id}_jsc"
        if pk =~ /^(\d+)_jsc$/
          jsc_id = $1.to_i
          { jsc_id: jsc_id }
        else
          raise "Invalid pk format for Jsc: #{pk}"
        end
      end

      def read(jsc_id:, ok_if_missing: false)
        check_for_nil!("jsc_id: #{jsc_id}", ok_if_nil: ok_if_missing) do
          from_dynamodb(dynamodb_record: db.read(pk: pk(jsc_id: jsc_id)))
        end
      end

      # Create a new JSC with the given ID
      def create!(jsc_id:)
        jsc = new(jsc_id: jsc_id)
        jsc.write!
      end
    end

    def pk
      @pk ||= self.class.pk(jsc_id: jsc_id)
    end

    # Add a user to this JSC
    # Return this object if modified, otherwise nil
    def add_user(user)
      return nil if members.include?(user.sub)

      self.members.unshift(user.sub)
      self
    end

    # Remove a user from this JSC
    # Return this object if modified, otherwise nil
    def remove_user(user)
      return unless members.include?(user.sub)

      self.members.delete(user.sub)
      self
    end

    # Get all users assigned to this JSC
    def users
      members.filter_map do |user_id|
        User.read(sub: user_id, ok_if_missing: true)
      end
    end

    def to_s
      "JSC-#{jsc_id}"
    end
  end
end
