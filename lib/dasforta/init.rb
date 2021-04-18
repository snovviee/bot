require_relative './trades'

key = 'mEdPeq7VctBQP0llyVX3q229MHH9Sbo'

bot = Bot::Trades.new(key)

bot.start
