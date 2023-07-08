require_relative 'account'
require_relative '../creds/xdopro'
require_relative '../creds/snovie'
require 'byebug'

Account.new.auth_code!
