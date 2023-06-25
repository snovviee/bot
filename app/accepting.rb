require_relative 'account'

Account.new

Account.all.each { |acc| acc.accept_market_offers! }
