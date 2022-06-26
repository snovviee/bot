m = gets.chomp.to_i
p = gets.chomp.to_i
n = gets.chomp.to_i

for x in 0..n
  puts m += (m * p / 100)
end
