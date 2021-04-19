require_relative 'market_trading'
require 'steam-trade'

module Bot
  class SendingItems < MarketTrading

    FILE_PATH = 'creds.json'

    attr_accessor :logged, :steam_inventory

    def initialize
      super

      @logged = set_steam_login
      @steam_inventory = set_steam_inventory
      try_to_write_cookies_to_file
    end

    def start_sending
      # byebug
      how_many_account_costs
      current_balance
      try_to_send_offers
    end

    private

    def get_cookies
      logged.get_auth_cookies
    end

    def try_to_write_cookies_to_file
      # If cookies was already setted, we should not create file again.
      return if File.exist?(FILE_PATH)

      File.open(FILE_PATH, 'w') { |f| f.puts get_cookies.to_json }
    end

    def set_steam_login
      if File.exist?(FILE_PATH)
        creds = JSON.parse File.read(FILE_PATH)

        return Handler.new(creds)
      end

      Handler.new(config['Username'], config['Password'],
                  config['SharedSecret'], true)
    rescue RuntimeError => error
      raise unless error.message == "Could not login using cookies"

      FileUtils.rm_rf(FILE_PATH)

      set_steam_login
    end

    def set_steam_inventory
      logged.mobile_info config['IdentitySecret']
      logged.normal_get_inventory(730)
    end

    def how_many_account_costs
      value = market_items.inject(0) { |sum,x| sum + x['price'].to_f }
      p "Account costs for now:  #{value} RUB"
    rescue NoMethodError
      retry
    end

    def try_to_send_offers
      response = p2p_request

      if response['error'] == 'Сделайте инвентарь публичным в настройках профиля Steam'

        update_inventory
        try_to_send_offers
      end

      try_to_send_offer_from(response) if response['success'] == true

      sleep(30)

      try_to_send_offers
    rescue
      retry
    end

    def try_to_send_offer_from(response)
      response['offers'].each do |offer|
        offer['items'].each do |market|
          item = find_item_from_steam_with(market)

          send_offer(item, offer)
        end
      end

      sleep(110)
    end

    def send_offer(item, offer)
      return unless item

      logged.send_offer(item, [], link_for(offer), offer['tradeoffermessage'])
      update_inventory
    end

    def find_item_from_steam_with(market)
      steam_inventory.detect do |steam|
        steam['assetid'].to_i == market['assetid'].to_i
      end
    end

    def link_for(offer)
      "https://steamcommunity.com/tradeoffer/new/?"\
      "partner=#{offer['partner']}&token=#{offer['token']}"
    end
  end
end
