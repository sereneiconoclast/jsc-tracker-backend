require 'db_fields/field'

module DbFields
  class ReadOnlyField < Field
    def define_accessor
      owner.attr_reader name
    end

    def writable?
      false
    end

    def metadata?
      true
    end
  end
end
