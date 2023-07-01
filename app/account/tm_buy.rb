require 'byebug'
require 'active_support/core_ext/module/delegation'
require_relative 'dmarket_account'
require_relative 'market_account/trade'

class TmBuy
  attr_reader :market_account, :dmarket_account

  GAME_ID = 'a8db'
  DOLLAR_TO_RUB = 74.0
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
  FILE_PATH = "tm_test.json"

  def initialize(market:, dmarket:)
    @dmarket_account = DmarketAccount.new(dmarket)
    @market_account = MarketAccount::Trade.new(market)
  end

  def buy!
    # loop do
    titles_with_ids.each_slice(5) do |sliced_titles_with_ids|
      sliced_titles_with_ids.each do |title_with_ids|
        best_offer = best_offer(title_with_ids)

        title = title_with_ids[:title]
        params = {
          Title: title,
          GameID: GAME_ID,
          Currency: 'USD',
          Period: '7D'
        }
        history_values = dmarket_account.history(params)[:SalesHistory]
        avg = average_from_history_values(history_values).round(2)
        next if avg.zero?

        mp_dollar = (best_offer / DOLLAR_TO_RUB).round(2)
        equation = avg / mp_dollar

        puts "EQUATION: #{equation}"
        if equation > 1
          existing_data = File.exist?(FILE_PATH) ? JSON.parse(File.read(FILE_PATH)) : {}

          market_link = "https://market-old.csgo.com/item/#{title_with_ids[:class_id]}-#{title_with_ids[:instance_id]}"
          dmarket_link = "https://dmarket.com/ru/ingame-items/item-list/csgo-skins?title=#{title}"

          data = {
            "#{title}": {
              equation: equation.round(2),
              dmarket: {
                price: avg,
                link: dmarket_link
              },
              market: {
                price: best_offer,
                price_incorrect_dollar: mp_dollar,
                link: market_link
              }
            }
          }

          updated_data = existing_data.merge(data)

          File.write(FILE_PATH, JSON.pretty_generate(updated_data))

          # File.open('tm_buy_test.txt', 'a+') do |f|
          #   f.write "EQUATION: #{equation.round(2)}, #{title}, DM: #{avg}$ TM: #{mp_dollar}$, links: #{market_link} | #{dmarket_link}"
          #   f.write "\n"
          # end
        end
      end
    end
    # end
  # rescue
    # retry
  end

  private

  def best_offer(title_with_ids)
    response = market_account.best_offer(
      title_with_ids[:class_id],
      title_with_ids[:instance_id]
    )
    return response.body[:best_offer].to_i / 100.0 if response.success?

    sleep(0.3)

    best_offer(title_with_ids)
  end

  def deviation_within_percentage?(number, reference, percentage)
    difference = (number - reference).abs
    deviation = (difference / reference.to_f) * 100
    deviation <= percentage
  end

  def average_from_history_values(history_values)
    prices = history_values[:Prices].map do |e|
      next if e.empty?

      price_in_cents = e.to_i
      price_in_cents / 100.0
    end.compact

    return 0 if prices.empty?

    prices.sum / prices.size
  end

  def items
    dmarket_account.inventory(
      GameID: 'a8db',
      Presentation: 'InventoryPresentationDetailed',
      Limit: 500,
      'BasicFilters.InMarket'.to_sym => true
    )
  end

  def titles
    market_items = build_list
    market_items.map { |e| e.last[:market_hash_name]  }
  end

  def titles_with_ids
    market_items = build_list
    market_items.map do |e|
      class_id, instance_id = e.first.to_s.split('_')

      {
        class_id: class_id,
        instance_id: instance_id,
        title: e.last[:market_hash_name]
      }
    end
  end

  def build_list # market_account/order.rb:207
    market_account.client.prices_rub_c_i.body[:items].select do |key, row|
      excluded = EXCLUDED_TITLES.detect { |e| row[:market_hash_name].match(e) }

      row[:price].to_f > 3 && !excluded && row[:popularity_7d].to_f > 2
    end
  end
end
