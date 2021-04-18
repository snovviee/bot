require_relative './trades'

key = '0Lr65Ufx4T5A8Z345sqkDoiwLCaPYhS'

bot = Bot::Trades.new(key)

bot.start
