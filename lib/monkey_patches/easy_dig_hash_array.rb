# Taken together, these two monkey patches allow you to do:
# a_hash >> 'key_to_an_array 5 another_key yet_another'

# { 'request' => { 'type' => 'Indecent' } } >> 'request type'
# => 'Indecent'
class ::Hash
  def >>(s)
    dig(*(s.split(' ')))
  end
end

# [:a, :b, :c].dig('1')
# => :b
class ::Array
  orig_dig = instance_method(:dig)

  define_method(:dig) do |*args|
    one = args[0]
    args[0] = one.to_i if one.is_a?(String) && /^[0-9]+$/ =~ one
    orig_dig.bind(self).call(*args)
  end
end
