def query(params)
  puts "Params: #{params}"
  [
    { name: 'John', surname: 'Doe', age: 33 },
    { name: 'John', surname: 'Doe', age: 34 },
    { name: 'John', surname: 'Doe', age: 35 }
  ]
end

class ActiveRecord
  # your code goes here
end

class User < ActiveRecord
end

ages = User.where(name: 'John').where(surname: 'Doe').order('age').map do |e|
  e[:age]
end

puts ages # => [33,34,35]

ages1 = User.where(name: 'John').order('age').where(surname: 'Doe').map do |e|
  e[:age]
end

puts ages1 # => [33,34,35]
