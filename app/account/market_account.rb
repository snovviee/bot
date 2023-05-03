require 'market_api'
require 'active_support/core_ext/module/delegation'

class MarketAccount
  attr_reader :client, :steam_api_key

  def initialize(options = {})
    @steam_api_key = options[:steam_api_key]
    @client = MarketApi::Client.new(
      api_key: options[:api_key]
    )
  end

  delegate :trade_check, :remove_all, :money_send, :ping, :update_inventory,
           :market_inventory, :steam_inventory, :list_items, :add_to_sale,
           :bind_steam_api_key, :best_offer, :set_prices, :balance, :p2p, to: :client

  def trading!
    remove_all if removing?
    money_send if allow_money_transfer

    loop do
      trade_check
      bind_steam_api_key('steam-api-key' => steam_api_key)

      ping

      update_inventory
      add_items_to_sale

      tmp_limits = item_limits

      150.times do
        ping
        change_price(tmp_limits)
      end
    end
  rescue => err
    puts err
    retry
  end

  private

  def removing?
    ENV.fetch('REMOVE_ITEMS', false)
  end

  def allow_money_transfer
    ENV.fetch('MONEY_TRANSFER', false)
  end

  def min_percent
    ENV.fetch('MIN_PERCENT', 1.0)
  end

  def max_percent
    min_percent + 0.5
  end

  def add_items_to_sale
    steam_inventory.body[:items].each_slice(5) do |s_items|
      threads = []

      s_items.each do |item|
        threads << Thread.new do
          add_to_sale(id: item[:id], price: 999999999, cur: 'RUB')
        end
      end

      threads.each(&:join)
      sleep(1)
    end

  rescue NoMethodError
    puts 'Trying to refetch'

    update_inventory
    add_items_to_sale
  end

  def item_limits
    result = Hash.new

    market_items = items
    item_names = market_items.map { |item| item[:market_hash_name] }.uniq

    item_names.each_slice(50) do |names|
      averages = average_price(names)
      market_items.each do |item|
        market_hash_name = item[:market_hash_name]
        next unless names.include?(market_hash_name)

        new_market_hash_name = market_hash_name
        if result[market_hash_name]
          unless result[:class_id] == item[:classid].to_i
            new_market_hash_name = market_hash_name + "_" + item[:classid]
          end
        end
        next if result[new_market_hash_name]

        result[new_market_hash_name] = {
          class_id: item[:classid].to_i,
          instance_id: item[:instanceid].to_i,
          min: averages[market_hash_name.to_sym][:average] * min_percent,
          max: averages[market_hash_name.to_sym][:average] * max_percent,
          price: 666666,
          id: item[:item_id]
        }
      end
    end

    result
  end

  def items
    response = market_inventory
    if response.success?
      response.body[:items]
    else
      []
    end
  end

  def change_price(limits)
    limits.each do |name, limit|
      response = best_offer(limit[:class_id], limit[:instance_id])
      offer = 0.0
      if response.success?
        offer = response.body[:best_offer].to_f / 100
      end

      next if offer == limit[:price] && offer <= limit[:max]

      limit[:price] = correct_price(offer, limit)
      response = set_prices(limit[:class_id], limit[:instance_id], (limit[:price] * 100).round)
    end
  rescue => err
    puts err
    retry
  end

  def correct_price(offer, limit)
    max = limit[:max]
    return max if offer.zero? || max == offer

    price = offer - 0.01
    price = max unless (limit[:min]..max).include?(price)

    price
  end

  def average_price(names)
    response = list_items('list_hash_name' => names)
    if response.success?
      response.body[:data]
    else
      average_price(names)
    end
  end
end
