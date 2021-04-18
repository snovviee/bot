require_relative './trades'

key = '9gaIxJoFwPmoyj7KUegQp8M3V8r50Gi'

bot = Bot::Trades.new(key)

bot.start
