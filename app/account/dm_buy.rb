require 'byebug'
require 'active_support/core_ext/module/delegation'
require_relative 'dmarket_account'
require_relative 'market_account/trade'

class DmBuy
  attr_reader :market_account, :dmarket_account

  DOLLAR_TO_RUB = 81.0
  # market_account/order.rb:10 for build_list
  EXCLUDED_TITLES = [
    'Sticker',
    'Souvenir',
    'Case',
    'Name Tag',
    'Capsule',
    'Sealed Graffiti',
    'RMR',
    'Patch',
    'Ground Rebel',
    'Gift Package'
  ]

  def initialize(market:, dmarket:)
    @dmarket_account = DmarketAccount.new(dmarket)
    @market_account = MarketAccount::Trade.new(market)
  end

  def buy!
    # titles = File.read("items.txt").split("\n").uniq

    while
      balance = get_dm_balance
      sleep 1
      break puts "Error balance: #{balance} USD" unless balance
      break if balance <= 0.5

      bought_items = get_bought_items_group
      sleep 1
      break puts "Error bought_items: #{balance} USD" unless bought_items

      titles.each_slice(5) do |s_titles|
        sleep 1
        market_response = market_account.list_items('list_hash_name' => s_titles)
        next unless market_response.success?

        market_data = market_response.body[:data]

        s_titles.each do |title|
          row = market_data[title.to_sym]
          market_price = calculated_average(row)
          next unless market_price

          market_price = (market_price / DOLLAR_TO_RUB).round(2)
          # market_price = (market_data[title.to_sym][:average] / DOLLAR_TO_RUB).round(2)

          Thread.new do
            dm_response = dmarket_account.title_offers(title: title)
            dm_response_objects = dm_response.body[:objects][0..2]
            sorted_objects = dm_response_objects.sort_by { |e| e[:price][:USD].to_f }

            result_offers = sorted_objects.map do |obj|
              quantity_bought_item = bought_items[obj[:title]]
              next if quantity_bought_item && quantity_bought_item >= 4
              next if obj[:title].include? 'Souvenir'

              next unless obj[:inMarket]

              obj_price = obj[:price][:USD].to_f
              equation = market_price * 100 / obj_price
              puts "EQUATION: #{equation}"
              next if equation < 1.8

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
          # Thread
          end
        # s_titles
        end
      # titles
      end
    # wile
    end

    puts "Remaining DMarket balance: #{get_dm_balance} USD"
  end

  private

  def get_dm_balance
    response = dmarket_account.balance
    return response.body[:usd].to_f / 100 if response.success?

    # should definitely get an answer
    # get_dm_balance
  end

  def items # dmarket_account.rb:81
    response = dmarket_account.inventory(
      GameID: 'a8db',
      Presentation: 'InventoryPresentationDetailed',
      Limit: 500,
      'BasicFilters.InMarket'.to_sym => true
    )
  return response if response.success?

  # should definitely get an answer
  # items
  end

  def get_bought_items_group
    return unless items

    items_bought = items.body[:Items]
    items_bought.group_by { |element| element[:Title] }.transform_values { |values| values.length }
  end

  def build_list # market_account/order.rb:207
    market_account.client.prices_rub_c_i.body[:items].select do |key, row|
      excluded = EXCLUDED_TITLES.detect { |e| row[:market_hash_name].match(e) }

      row[:price].to_f > 3 && !excluded && row[:popularity_7d].to_f > 2
    end
  end

  def titles
    market_items = build_list
    market_items.map { |e| e.last[:market_hash_name]  }
  end

  def calculated_average(row)
    result_5 = {
      count: 0,
      prices: []
    }
    result_10 = {
      count: 0,
      prices: []
    }
    range_5 = five_days_range
    range_10 = ten_days_range

    row[:history].each do |e|
      if range_5.include?(e.first)
        result_5[:count] += 1
        result_5[:prices].push(e.last)
      end

      if range_10.include?(e.first)
        result_10[:count] += 1
        result_10[:prices].push(e.last)
      end
    end

    return if result_5[:count] < 10

    sorted_prices = result_5[:prices].sort
    without_gap_prices = sorted_prices[2..-3]
    actual_count = (without_gap_prices.size * 0.35).round
    without_gap_prices[-actual_count..-1].sum / actual_count
  end

  def five_days_range
    now = Time.now
    past = now - 5.days
    (past.to_i..now.to_i)
  end

  def ten_days_range
    now = Time.now
    past = now - 10.days
    (past.to_i..now.to_i)
  end
end
