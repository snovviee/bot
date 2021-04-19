require_relative 'market_api_methods'
require_relative '../bot'

module Bot
  class MarketTrading < Bot
    include MarketApiMethods

    attr_accessor :market_api_key

    def initialize
      super

      @market_api_key = config['MarketApiKey']
    end

    def start_trading
      remove_items_from_trade if ENV['REMOVING'] == true
      money_send if ENV['MONEY'] == true

      p "Items left: #{market_items.count}"

      ping
      update_inventory
      add_items_to_sale

      item_limits = get_item_limits

      300.times do
        ping
        change_item_price_with item_limits
      end

      start_trading
    rescue NoMethodError
      retry
    end

    private

    def searching_api_key
      config['SecondaryMarketApiKey']
    end

    def minimum_percent
      config['MinimumPercent'].to_f
    end

    def maximum_percent
      minimum_percent + 0.5
    end
  end
end
