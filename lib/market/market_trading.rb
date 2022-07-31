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

    def ws_auth
      get request('api/v2/get-ws-auth')
    end

    def ping
      # p "PING SUPER PUPER"
      # byebug
      p (get request('api/PingPong/direct'))['ping']
    end

    def start_trading
      loop do
        remove_items_from_trade if ENV['REMOVING'] == "true"
        if ENV['MONEY'] == "true"
          money_send
          p 'Balance was transfered'
        end

        ping
        trade_check
        update_inventory
        p 'Inventory was updated'
        add_items_to_sale
        p 'Items was added'
        tmp_limits = get_item_limits
        p 'Limits was got'
        150.times do
          ping
          change_item_price_with tmp_limits
        end
      end
    end

    private

    def trade_check
      result = (get request('api/Test') )['status']['trade_check']
      msg = result ? 'ALL IS GOOD, NO BAN' : 'WHOOOOOOPS, YOUR WAS BANNED'
      puts msg
    end

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
