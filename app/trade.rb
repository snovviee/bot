require_relative 'account'

Account.new

Account.all.each { |acc| Thread.new { acc.trading! } }
Account.all.each { |acc| acc.send_offers! }
