print "Number of persons: "
input_count = gets.chomp

# puts input_count
# require 'byebug'
arr = []
input_count.to_i.times do |i|
  print "Person name: "
  arr << gets.chomp
end

# arr = ["a", "b", "c", "d"]

def bla(arr, new_arr = [])
  if arr.one?
    new_arr << arr.shift + '-' + new_arr.sample[/^([\w\W]+)\-/, 1]

    return new_arr
  end
  return new_arr if arr.empty?

  person = arr.shift
  chained = arr.sample
  new_arr << person + '-' + chained
  bla(arr, new_arr)
end

a = bla(arr)
puts a
