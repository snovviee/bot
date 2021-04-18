require_relative './trades'

key = 'H0U4uj28oAhRg0IcTSGVhX1sOnGj3au'

bot = Bot::Trades.new(key)

bot.start
