# Allow setting the flag to enable debugging on a per-class basis
class ::Class
  def debug_me!
    @debug_me = true
  end

  def debug_me?
    @debug_me
  end
end

module ::Kernel
  # When called in an instance method context, delegate to the instance's class
  def debug_me?
    self.class.debug_me?
  end

  def debug(s)
    puts("#{self.class} - #{Time.now} - #{s}") if debug_me?
  end
end