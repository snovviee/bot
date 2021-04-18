require_relative './trades'

key = 'Adu9Ps34GdP1VF1KBdLPM2f2SLxk7TI'

bot = Bot::Trades.new(key)

bot.start
