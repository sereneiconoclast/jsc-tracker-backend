require 'job_slog/field'

module DbFields
  class IdField < Field
    def metadata?
      true
    end

    def id?
      true
    end

    def define_accessor
      owner.attr_reader name
      the_field = self
      owner.define_method("#{name}=".to_sym) do |new_val|
        iname = "@#{the_field.name}".to_sym
        val = instance_variable_get(iname)
        raise "Can't set ID field #{the_field} to #{new_val}, already set to #{val}" unless val.nil?
        instance_variable_set(iname, new_val)
      end
    end

    def validate!(obj)
      val = obj.public_send(name)
      raise "#{obj}: No value set for #{self}" if val.nil?
    end
  end
end
