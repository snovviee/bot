require_relative '../sending'

bot = Bot::Sending.new(Dir.pwd[/lib\/([\w\W]+)$/, 1])

bot.start
