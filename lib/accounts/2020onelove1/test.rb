def handle_input_answer(msg)
  return unless gets.strip.capitalize == 'Y'

  print msg

  yield
end

arr = []

while true
  print 'Do you want to add new name to list? (y/n) '
  handle_input_answer('Please write name u wish add to list ') do
    arr << gets.strip.capitalize
  end

  p arr.map { |el| "#{el}  #{arr.index(el) + 1}" }

  print 'Do you want to remove anybody from list? (y/n) '
  handle_input_answer('Please write index u wish remove from list ') do
    index = gets.strip
    index = index.to_i if index[/^\d+$/]
    puts "#{arr.delete_at(index - 1)} was removed"
  end
end
