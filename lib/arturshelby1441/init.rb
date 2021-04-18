require_relative './trades'

key = '8Z5i856eM8t0d79c1d0m8L2oI0u8NWY'

bot = Bot::Trades.new(key)

bot.start
