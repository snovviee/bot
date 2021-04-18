require_relative './trades'

key = '0AKM82szj13mKoO0923ga68W8INFq5e'

bot = Bot::Trades.new(key)

bot.start
