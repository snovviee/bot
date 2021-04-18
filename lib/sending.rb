require_relative './market'
require 'steam-trade'
require 'httparty'

module Bot
  class Sending < Market

    attr_accessor :file_name, :config, :user_key

    def initialize(file_name)
      file = File.open("./#{file_name}.json")
      @config = JSON.parse file.read
      @user_key = config['user_key']
      file.close

      @file_name = file_name
      @logged = logged

      write_cookies_to_file
    end

    def start
      acc_cost

      steam_inventory
      balance
      try_to_send_offers
    rescue
      retry
    end

    private

    def get_cookies
      logged.get_auth_cookies
    end

    def balance
      url = "https://market.csgo.com/api/GetMoney/?key="\
            "#{user_key}"
      p "current balance: #{get(url)['money'].to_i * 0.01}"
    end

    def market_items
      url = "https://market.csgo.com/api/v2/items?key="\
            "#{user_key}"
      get(url)['items']
    end

    def acc_cost
      value = market_items.inject(0) { |sum,x| sum + x['price'].to_i }
      p "total_account_value:  #{value}"
    end

    def update_inventory
      url = "https://market.csgo.com/api/UpdateInventory/?key="\
            "#{user_key}"
      p "Inventory status: #{get(url)['success'] == true}."
    rescue JSON::ParserError
      retry
    end

    def get(url, headers = nil)
      HTTParty.get(url, headers: headers)
    end

    def write_cookies_to_file
      # If cookies was already setted, we should not create file again.
      return if File.exist?(file_path)

      cookies = get_cookies
      File.open(file_path, 'w') { |f| f.puts cookies.to_json }
    end

    def file_path
      "../#{file_name}/creds.json"
    end

    def logged
      return @logged if @logged

      if File.exist?(file_path)
        file = File.open(file_path)
        creds = JSON.parse file.read
        file.close

        return @logged = Handler.new(creds)
      end

      username = config['username']
      password = config['password']
      shared_key = config['shared_key']
      remember_me = true

      Handler.new(username, password, shared_key, remember_me)
    rescue RuntimeError => error
      raise unless error.message == "Could not login using cookies"

      FileUtils.rm_rf(file_path)

      logged
    end

    def identity_key
      config['identity_key']
    end

    def p2p_request
      url = "https://market.csgo.com/api/v2/trade-request-give-p2p-all?key=#{user_key}"
      get(url)
    end

    def steam_inventory
      return @steam_inventory if @steam_inventory

      logged.mobile_info(identity_key)

      @steam_inventory = logged.normal_get_inventory(730)
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
