require 'db_fields/field'

module DbFields
  class IdListField < Field
    def from_dynamodb(dval)
      # Handle empty arrays from DynamoDB
      return [] if dval.nil? || dval.empty?
      dval
    end

    def to_dynamodb(val)
      # Ensure we always store an array, even if empty
      val || []
    end

    def to_json_value(val)
      val.to_a
    end

    def validate!(obj)
      # Check for duplicates in the list
      list_value = obj.public_send(name)
      return unless list_value.is_a?(Array)

      duplicates = list_value.group_by { |id| id }.select { |_id, group| group.size > 1 }.keys
      unless duplicates.empty?
        raise "Duplicate IDs found in #{name}: #{duplicates.join(', ')}"
      end
    end

    def prepend_id(obj, new_id)
      # Add new ID to the front of the list
      current_list = obj.public_send(name) || []

      # Remove the ID if it already exists (to avoid duplicates)
      filtered_list = current_list.reject { |id| id == new_id }

      # Prepend the new ID
      new_list = [new_id] + filtered_list

      # Set the new list
      obj.public_send("#{name}=", new_list)
    end

    def move_id_to_front(obj, id_to_move)
      # Move an existing ID to the front of the list
      current_list = obj.public_send(name) || []

      # Remove the ID if it exists
      filtered_list = current_list.reject { |id| id == id_to_move }

      # Prepend the ID to the front
      new_list = [id_to_move] + filtered_list

      # Set the new list
      obj.public_send("#{name}=", new_list)
    end
  end
end
