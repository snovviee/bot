require_relative './trades'

key = '5c5g5ctetdoB7029NmvoF0NnXtDyneF'

bot = Bot::Trades.new(key)

bot.start
