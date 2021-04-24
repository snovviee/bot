require_relative 'signature_builder'
require_relative 'dmarket_api_methods'
require_relative 'redefined_market_api_methods'
require_relative '../bot'

module Bot
  class DmarketTrading < Bot
    include DmarketApiMethods
    include SignatureBuilder
    include RedefinedMarketApiMethods

    SEARCHING_API_KEY = '36aE1oXFB3hMDU30Q2PdZ5K7qjb1w12'

    attr_accessor :public_key, :private_key, :request_url, :request_method,
                  :request_body, :title

    def initialize
      super

      @public_key = config['DmarketPublicKey']
      @private_key = config['DmarketPrivateKey'].gsub @public_key, ''
    end

    def start_buying
      process_buy_items
    end
  end
end
