require 'market_api'
require 'active_support/core_ext/module/delegation'

module MarketAccount
  class Base
    attr_reader :client

    def initialize(options = {})
      @steam_api_key = options[:steam_api_key]
      @client = MarketApi::Client.new(
        api_key: options[:api_key]
      )
    end

    private

    def average_price(names)
      response = list_items('list_hash_name' => names)
      if response.success?
        response.body[:data]
      else
        average_price(names)
      end
    end
  end
end
