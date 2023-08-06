require 'byebug'
require 'active_support/core_ext/module/delegation'
require_relative 'dmarket_account'
require_relative 'market_account/trade'
require_relative 'steam_account'

class DmSale
  attr_reader :market_account, :dmarket_account, :steam_account

  GAME_ID = 'a8db'
  GAME_ID_TITLE = 'CSGO'
  RUB_TO_DOLLAR = 90.0
  DATE = '2023-6-26'
  DATE_END = '2023-7-20'

  def initialize(market:, dmarket:, steam:)
    @dmarket_account = DmarketAccount.new(dmarket)
    @market_account = MarketAccount::Trade.new(market)
    @steam_account = SteamAccount.new(steam)
  end

  def min_percent
    ENV.fetch('MIN_PERCENT_DM', 1.0).to_f
  end

  def max_percent
    min_percent + 0.5
  end

  def sale!
    loop do
      # transfer_from_steam_to_dm
      updating_dm_cs_inventory

      dm_limits = item_limits
      150.times do
        updating_dm_cs_inventory
        change_price(dm_limits)
        sleep 30
      end
    end
  rescue => err
    puts err
    retry
  end

  def change_price(limits)
    limits.each do |title, limit|
      dm_objects_by_title = get_dm_objects_by_title(title)
      item_prices = dm_objects_by_title.map { |i| i[:price][:USD].to_f / 100 }
      best_offer = item_prices.min
      next if best_offer == limit[:price] && best_offer <= limit[:max]

      limit[:price] = correct_price(limit, item_prices)
      offers = limit[:dm_offers].map do |offer|
        {
          "OfferID" => offer[:offer_id],
          "AssetID" => offer[:asset_id],
          "Price" => { "Currency" => 'USD',"Amount"=> (limit[:price]).round(2) }
        }
      end
      dmarket_account.user_offers_edit("Offers" => offers)
    end
  rescue => err
    puts err
    retry
  end

  def get_dm_objects_by_title(title, count = 50)
    dm_response = dmarket_account.title_offers(title: title)
    dm_response_objects = dm_response.body[:objects]
    correct_dm_response_objects_by_title = dm_response_objects.select {|obj| obj[:title] == title }
    sorted_objects = correct_dm_response_objects_by_title.sort_by { |e| e[:price][:USD].to_f }
    sorted_objects[0..count]
  end

  def correct_price(limit, item_prices)
    min = limit[:min]
    max = limit[:max]
    my_item_prices = limit[:dm_offers].map { |offer| offer[:price] }
    item_prices_without_me = item_prices - my_item_prices
    best_offer = item_prices_without_me.min
    price = best_offer - 0.01
    if limit[:price] + 0.1 < best_offer || !(min..max).include?(price)
      return item_prices.detect { |i_price| i_price >= min } || max - 0.01
    end

    price
  end

  def item_limits
    dm_offers = collect_dm_offers
    item_titles = dm_offers.map { |item| item[:title] }.uniq
    same_items = dm_offers.each_with_object(Hash.new(0)) { |item, counts| counts[item[:title]] += 1 }

    averages = average_price(item_titles, same_items)
    item_titles.each_with_object(Hash.new) do |title, result|
      result[title] = {
        min: (averages[title] * min_percent).round(2),
        max: (averages[title] * max_percent).round(2),
        price: 98765,
        dm_offers: dm_offers.select { |i| i[:title] == title }
      }
    end
  end

  def collect_dm_offers
    dm_offers = dm_offers_response.body[:Items]
    dm_offers.map do |item|
      offer = item[:Offer]
      {
        title: item[:Title],
        price: offer[:Price][:Amount],
        asset_id: item[:AssetID],
        offer_id: offer[:OfferID],
      }
    end
  end

  def dm_offers_response
    response = dmarket_account.user_offers
    return response if response.success?

    sleep 10
    dm_offers_response
  end

  def average_price(titles, same_items)
    tm_bought_items = collect_tm_bought_items

    titles.each_with_object(Hash.new) do |title, result|
      count_items_on_sale = same_items[title]
      same_bought_item = tm_bought_items.select { |i| i[:title] == title }[0...count_items_on_sale]
      average = same_bought_item.sum(0.0) { |i| i[:price_usd] } / count_items_on_sale
      result[title] = average.round(2)
    end
  end

  def collect_tm_bought_items
    tm_buy_history = tm_buy_history_response.body[:data]
    tm_buy_history.map do |item|
      next unless item[:event] == 'buy'
      next unless item[:stage] == '2'

      price = item[:paid].to_f
      price_usd = item[:currency] == 'RUB' ? (price / 100 / RUB_TO_DOLLAR).round(2) : (price / 1000).round(2)
      {
        title: item[:market_hash_name],
        price_usd: price_usd,
        time: item[:time]
      }
    end.compact
  end

  def tm_buy_history_response
    date_unix = Time.parse(DATE).to_i
    date_end_unix = Time.parse(DATE_END).to_i
    response = market_account.operation_history(date_unix, date_end_unix)
    return response if response.success?

    sleep 10
    tm_buy_history_response
  end

  def updating_dm_cs_inventory
    dmarket_account.inventory_sync(Type: 'Inventory', GameID: GAME_ID_TITLE)
  end

  def transfer_from_steam_to_dm
    updating_dm_cs_inventory
    steam_items.each do |item|
      dmarket_account.deposit_assets({AssetID: [item[:AssetID]]})
      sleep 20
    end
  end

  def steam_items
    response = dmarket_account.inventory(GameID: GAME_ID, Presentation: 'InventoryPresentationDetailed', Limit: 500)
    if response.success?
      response.body[:Items]
    end
  end

  def items_in_dm
    response = dmarket_account.inventory(
      GameID: GAME_ID,
      Presentation: 'InventoryPresentationDetailed',
      Limit: 500,
      'BasicFilters.InMarket'.to_sym => true
    )

    if response.success?
      response.body[:Items]
    end
  end
end
