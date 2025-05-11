require 'db_fields/read_only_field'

module DbFields
  # Like a ReadOnlyField but can be set at construction time
  class IdField < ReadOnlyField
    def define_accessor
      super
      field_name = name
      owner.define_method("initialize_#{field_name}".to_sym) do |value|
        old_value = public_send(field_name)
        raise "Already set: #{old_value} (can't set to #{value})" if old_value
        instance_variable_set("@#{field_name}".to_sym, value)
      end
    end
  end
end
