require 'faye/websocket'
require_relative '../../market/market_trading'
require 'eventmachine'
require 'byebug'

@bot = Bot::MarketTrading.new


BASE_URL = 'wss://wsn.dota2.net/wsn/'

def auth
  @bot.ws_auth['wsAuth']
end

EM.run do
  open    = proc { puts 'connected' }
  message = proc do|e|
    puts e.data
  end
  error   = proc { |e| puts e }
  close   = proc do
    puts 'closed'
  end
  methods = { open: open, message: message, error: error, close: close }

  client = Faye::WebSocket::Client.new(BASE_URL)
  EventMachine.add_periodic_timer(15) do
    client.send('ping')
  end

  client.send(auth)

  client.tap do |websocket|
    methods.each_pair do |key, method|
      websocket.on(key) { |event| method.call(event) }
    end
  end
end
