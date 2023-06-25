require_relative 'account'

Account.new

Account.all.each { |acc| Thread.new { acc.withdraw! } }
Account.all.each { |acc| acc.accept_offers! }
