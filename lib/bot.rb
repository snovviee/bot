require 'httparty'
require 'open-uri'
require 'byebug'
require 'json'
require_relative './helpers/http_request_helpers'
require_relative '../config/account_config'

module Bot
  class Bot
    include HttpRequestHelpers
    include AccountConfig

    attr_accessor :config

    def initialize
      @config = account_config
    end
  end
end
