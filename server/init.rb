require 'json'
require 'byebug'

def trade
  @trade ||= Thread.new { p 'Trade started' }
end

order = Thread.new { 'Order started' }
buy = Thread.new { 'Buy started' }
withdrawal = Thread.new { 'Withdrawal started' }

loop do
  data = File.read('settings.json')
  json_data = JSON.parse(data, symbolize_names: true)
  if json_data[:trade][:enable]
    trade
  end
  byebug
rescue
  next
end
