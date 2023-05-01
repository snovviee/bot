require 'steam-trade'

class SteamAccount
  attr_reader :username, :password, :shared_secret, :identity_secret

  APP_ID = 730

  def initialize(options = {})
    @username = options[:username]
    @password = options[:password]
    @shared_secret = options[:shared_secret]
    @identity_secret = options[:identity_secret]
  end

  def accept_offers!
    loop do
      begin
        inventory
        logged.get_trade_offers['trade_offers_received'].each do |offer|
          next unless offer['message'].size == 36

          logged.accept_trade_offer(offer['tradeofferid'])
          sleep(1)
        end
      rescue => err
        puts err
        sleep(10)
        retry
      end

      sleep(30)
    end
  end

  def logged
    @logged ||= begin
      Handler.new(
        username,
        password,
        shared_secret,
        true
      )
    end
  end

  def inventory
    @inventory ||= begin
      logged.mobile_info(identity_secret)
      logged.normal_get_inventory(APP_ID)
    end
  end

  private

  def send_offers!(offers)
    offers.each do |offer|
      offer[:items].each do |item|
        i_item = inventory.detect do |i_item|
          i_item[:assetid].to_i == item[:assetid].to_i
        end
        next unless i_item

        logged.send_offer(
          i_item,
          [],
          offer_link(offer),
          offer['tradeoffermessage']
        )
      end
    end
  end

  def offer_link(offer)
    "https://steamcommunity.com/tradeoffer/new/?"\
    "partner=#{offer['partner']}&token=#{offer['token']}"
  end
end
