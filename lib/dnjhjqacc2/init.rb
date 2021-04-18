require_relative './trades'

key = 'v71TObVoqy2o2kI25tk4A70d3hXGHhu'

bot = Bot::Trades.new(key)

bot.start
