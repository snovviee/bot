require 'market_api'
require 'byebug'
require 'active_support/core_ext/module/delegation'
require_relative 'dmarket_account'
require_relative 'steam_account'
require_relative 'market_account'

class Account
  def self.all
    @all ||= []
  end

  attr_reader :market_account, :dmarket_account, :steam_account

  def initialize(market:, dmarket:, steam:)
    @dmarket_account = DmarketAccount.new(dmarket)
    @steam_account = SteamAccount.new(steam)
    @market_account = MarketAccount.new(market)
    Account.all << self
  end

  delegate :withdraw!, :get_items_into_file!, to: :dmarket_account
  delegate :accept_offers!, to: :steam_account
  delegate :trading!,       to: :market_account

  def send_offers!
    show_market_balance
    try_to_send_offers
  end

  def buy!
    titles = File.read("items.txt").split("\n").uniq

    titles.each_slice(16) do |s_titles|
      market_response = market_account.list_items('list_hash_name' => s_titles)
      market_data = market_response.body[:data]

      s_titles.each do |title|
        market_price = (market_data[title.to_sym][:average] / 81.0).round(2)

        Thread.new do
          dm_response = dmarket_account.title_offers(title: title)
          dm_response_objects = dm_response.body[:objects]
          sorted_objects = dm_response_objects.sort_by { |e| e[:price][:USD].to_f }

          result_offers = sorted_objects.map do |obj|
            next if obj[:title].include? 'Souvenir'

            next unless obj[:inMarket]

            obj_price = obj[:price][:USD].to_f
            equation = market_price * 100 / obj_price
            next if equation < 1.7

            {
              offerId: obj[:extra][:offerId],
              price: {
                amount: obj[:price][:USD],
                currency: 'USD'
              },
              type: 'dmarket'
            }
          end.compact

          unless result_offers.empty?
            buy_body = { offers: result_offers }.to_json
            dmarket_account.buy(buy_body)
          end
        end
      end
    end

    response = dmarket_account.balance
    if response.success?
      balance = response.body[:usd].to_f / 100
      puts "Remaining DMarket balance: #{balance} USD"
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
    response = market_account.balance
    if response.success?
      balance = response.body[:money] * 0.01
      puts "Current Balance: #{balance} RUB"
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
    if response.body[:success] == true
      try_to_send_offer_from(response.body)
      market_account.update_inventory

      show_market_balance
    end

    sleep(30)

    try_to_send_offers
  rescue => err
    puts err
    retry
  end
end