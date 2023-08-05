require 'byebug'
require 'active_support/core_ext/module/delegation'
require_relative 'dmarket_account'
require_relative 'market_account/trade'

class DmBuy
  attr_reader :market_account, :dmarket_account

  DOLLAR_TO_RUB = 95.0
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
      puts "Remaining DMarket balance: #{get_dm_balance} USD"
      sleep 1
      break if balance <= 0.10

      bought_items = get_bought_items_group
      sleep 1

      titles.each_slice(5) do |s_titles|
        sleep 1
        market_response = market_account.list_items('list_hash_name' => s_titles)
        next unless market_response.success?

        market_data = market_response.body[:data]

        s_titles.each do |title|
          row = market_data[title.to_sym]
          # market_price = (market_data[title.to_sym][:average] / DOLLAR_TO_RUB).round(2)
          market_price = calculated_average(row)
          next unless market_price

          Thread.new do
            result_offers = get_dm_objects_by_title(title).map do |obj|
              next unless obj[:inMarket]
              next unless all_conditions_to_buy?(obj, market_price, bought_items)

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
  rescue => e
    puts "Error #{e}"
    retry
  end

  private

  def get_dm_balance
    response = dmarket_account.balance
    return response.body[:usd].to_f / 100 if response.success?

    # should definitely get an answer
    puts "Error! #{response.status}, #{response.reason_phrase}"
    get_dm_balance
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
    puts "Error! #{response.status}, #{response.reason_phrase}"
    items
  end

  def get_bought_items_group
    items_bought = items.body[:Items]
    items_bought.group_by { |element| element[:Title] }.transform_values { |values| values.length }
  end

  def titles
    market_items = build_list
    market_items.map { |e| e.last[:market_hash_name]  }
  end

  def build_list # market_account/order.rb:207
    market_account.client.prices_rub_c_i.body[:items].select do |key, row|
      excluded = EXCLUDED_TITLES.detect { |e| row[:market_hash_name].match(e) }

      row[:price].to_f > 3 && !excluded && row[:popularity_7d].to_f > 2
    end
  end

  def get_dm_objects_by_title(title, count = 2)
    dm_response = dmarket_account.title_offers(title: title)
    dm_response_objects = dm_response.body[:objects]
    correct_dm_response_objects_by_title = dm_response_objects.select {|obj| obj[:title] == title }
    sorted_objects = correct_dm_response_objects_by_title.sort_by { |e| e[:price][:USD].to_f }
    sorted_objects[0..count]
  end

  def all_conditions_to_buy?(obj, market_price, bought_items)
    quantity_bought_item = bought_items[obj[:title]] || 0
    return if quantity_bought_item >= 4
    return if obj[:title].include? 'Souvenir'

    obj_price = obj[:price][:USD].to_f / 100
    return if obj_price > 5

    equation = market_price / obj_price
    return if equation > 4
    return if equation < 1.9

    puts "EQUATION: #{equation}, DM: #{obj[:title]} - #{obj_price} TM: #{market_price} COUNT: #{quantity_bought_item}"

    # return if quantity_bought_item >= 3 && obj_price > 0.4
    # return if quantity_bought_item >= 2 && obj_price > 0.7
    # return if quantity_bought_item >= 1 && obj_price > 1.4

    true
  end

  CALCULATED_OPTION = { days: 30,
                        sales_per_days: 25,
                        delete_min: 2,
                        delete_max: 13,
                        percentage_of_sales_quantity: 80,
                        percentage_off_min_price: true }

  def calculated_average(row)
    result = { count: 0, prices: [] }
    range = days_range

    row[:history].each do |e|
      if range.include?(e.first)
        result[:count] += 1
        result[:prices].push(e.last)
      end
    end

    return if result[:count] < CALCULATED_OPTION[:sales_per_days]

    sorted_prices = result[:prices].sort
    without_gap_prices = sorted_prices[CALCULATED_OPTION[:delete_min]...-CALCULATED_OPTION[:delete_max]]
    actual_count = (without_gap_prices.size * CALCULATED_OPTION[:percentage_of_sales_quantity].to_f / 100).round
    if CALCULATED_OPTION[:percentage_off_min_price]
      price = without_gap_prices[0...actual_count].sum / actual_count
    else
      price = without_gap_prices[-actual_count..-1].sum / actual_count
    end

    return unless price

    (price / DOLLAR_TO_RUB).round(2)
  end

  def days_range
    now = Time.now
    past = now - CALCULATED_OPTION[:days].days
    (past.to_i..now.to_i)
  end
end
