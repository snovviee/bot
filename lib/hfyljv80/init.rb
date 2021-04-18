require_relative './trades'

key = 'VZ7Hc1CBL4ASP1mo4n5n7KRmL0rc0M0'

bot = Bot::Trades.new(key)

bot.start
