require_relative './trades'

key = 'ATT3D35e2E098HCKMTvRX7p1mD1cUFz'

bot = Bot::Trades.new(key)

bot.start
