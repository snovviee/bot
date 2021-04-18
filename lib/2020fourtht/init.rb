require_relative './trades'

key = 'tFPRHrUW1Mn2t9DU4fz5s6Wj8QR6z03'

bot = Bot::Trades.new(key)

bot.start
