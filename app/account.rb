require 'market_api'
require 'byebug'
require 'active_support/core_ext/module/delegation'
require_relative 'account/dmarket_account'
require_relative 'account/steam_account'
require_relative 'account/market_account/trade'
require_relative 'account/market_account/order'
require_relative 'account/dm_buy'
require_relative 'account/tm_buy'
require_relative 'account_data_settings'

class Account
  include AccountDataSettings

  def self.all
    @all ||= []
  end

  attr_reader :market_account, :dmarket_account, :steam_account, :order, :dm_buy, :tm_buy

  def initialize
    @dmarket_account = DmarketAccount.new(settings[:dmarket])
    @steam_account = SteamAccount.new(settings[:steam])
    @market_account = MarketAccount::Trade.new(settings[:market])
    @order = MarketAccount::Order.new(settings[:market])
    @dm_buy = DmBuy.new(market: settings[:market], dmarket: settings[:dmarket])
    @tm_buy = TmBuy.new(market: settings[:market], dmarket: settings[:dmarket])

    Account.all << self
  end

  delegate :withdraw!, :get_items_into_file!, to: :dmarket_account
  delegate :accept_offers!, :auth_code!, to: :steam_account
  delegate :trading!,       to: :market_account
  delegate :build!,         to: :order
  delegate :buy!,           to: :order, prefix: :order
  delegate :buy!,           to: :dm_buy
  delegate :buy!,           to: :tm_buy, prefix: :tm

  def send_offers!
    show_market_balance
    try_to_send_offers
  end

  def accept_market_offers!
    loop do
      begin
        inventory
        logged.get_trade_offers['trade_offers_received'].each do |offer|
          trades = market_account.client.trades(extended: 1).body[:trades]
          is_trade = trades.detect { |e| e[:trade_id] == offer["tradeofferid"] }
          next unless offer['message'].size == 36 || is_trade

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

  def order_trade!
    loop do
      build!
      order_buy!
    end
  end

  private

  def logged
    @logged ||= steam_account.logged
  end

  def inventory
    @inventory ||= steam_account.inventory
  end

  def show_market_balance
    response = market_account.balance_v2
    if response.success?
      balance = response.body[:money] * 0.001
      puts "Current Balance: #{balance} USD"
    end
  end

  def try_to_send_offer_from(body)
    body[:offers].each do |offer|
      offer[:items].each do |item|
        send_offer(item, offer)
      end
    end
  end

  def send_offer(item, offer)
    handled = inventory.detect do |i|
      i["assetid"].to_i == item[:assetid].to_i
    end
    return unless handled

    link = "https://steamcommunity.com/tradeoffer/new/?"\
           "partner=#{offer[:partner]}&token=#{offer[:token]}"
    logged.send_offer(handled, [], link, offer[:tradeoffermessage])
  end

  def try_to_send_offers
    response = market_account.p2p
    if response.success? && response.body[:success] == true
      try_to_send_offer_from(response.body)
      market_account.update_inventory_v2

      show_market_balance
    end

    sleep(30)

    try_to_send_offers
  rescue => err
    puts err
    retry
  end
end
