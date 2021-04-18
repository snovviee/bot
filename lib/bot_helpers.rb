require 'net/http'
require 'json'
require 'open-uri'
require 'byebug'

module Bot
  module BotHelpers

    private

    def get(url)
      Net::HTTP.get URI(url)
    end

    def get_value(url, key)
      response = JSON.parse(get(url))
      response[key]
    end
  end
end
