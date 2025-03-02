class ::Time
  class << self
    def my_format(n)
      Time.at(n.to_i).strftime('%Y-%m-%d %H:%M:%S')
    end
  end
end
