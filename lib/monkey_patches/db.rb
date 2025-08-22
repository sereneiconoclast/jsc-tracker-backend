require 'db'

module ::Kernel
  def db
    $db ||= begin
      DB.new(table: 'JSC-Tracker', region: JSC_REGION)
    end
  end
end
