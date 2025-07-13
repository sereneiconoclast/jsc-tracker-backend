require 'db_fields/field'

module DbFields
  class IdListField < Field
    def from_dynamodb(dval)
      # DynamoDB should never _give_ us a nil, but we might encounter this if
      # the field is unset in a record for some reason
      dval || []
    end

    def to_dynamodb(val)
      # Ensure we always store an array, even if empty
      val || []
    end

    def validate!(obj)
      # Check for duplicates in the list
      list_value = obj.public_send(name)
      raise "#{obj}##{name} - Should be an array: #{list_value.inspect}" unless list_value.is_a?(Array)

      bad_values = list_value.find_all { |v| !v.is_a?(String) }
      unless bad_values.empty?
        raise "#{obj}##{name} - Non-string values: #{bad_values.inspect}"
      end

      # The group_by yields { "id1" => ["id1", "id1"], "id2" => ["id2"], ... }
      # Then throw out anything with a size of 1, and just keep a string describing
      # the ID and how many occurrences were seen
      duplicates = list_value.group_by { |id| id }.filter_map do |id, group|
        group.size > 1 ? "#{id} (#{group.size})" : nil
      end
      unless duplicates.empty?
        raise "#{obj}##{name} - Duplicate IDs found: #{duplicates.join(', ')}"
      end
    end

    # Add new ID to the front of the list, or move it there if already present
    def prepend_id(obj, new_id)
      current_list = obj.public_send(name) || []

      # Remove the ID if it already exists (to avoid duplicates)
      filtered_list = current_list - [new_id]

      # Prepend the new ID
      new_list = [new_id] + filtered_list

      # Set the new list
      obj.public_send("#{name}=", new_list)
    end
  end
end
