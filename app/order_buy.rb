require_relative 'account'

Account.new

Thread.abort_on_exception = true

Account.all.each { |acc| Thread.new { acc.order_trade! } }
Account.all.each { |acc| acc.accept_market_offers! }
