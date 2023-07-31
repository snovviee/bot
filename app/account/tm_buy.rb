require 'byebug'
require 'active_support/core_ext/module/delegation'
require_relative 'dmarket_account'
require_relative 'market_account/trade'

class TmBuy
  attr_reader :market_account, :dmarket_account, :market_api

  GAME_ID_CS = 'a8db'
  DOLLAR_TO_RUB = 90.0
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
    @market_api = market[:api_key]
  end

  def buy!
    loop do
      titles_with_ids.each_slice(5) do |sliced_titles_with_ids|
        sliced_titles_with_ids.each do |title_with_ids|
          best_offer = best_offer(title_with_ids)
          next if best_offer.zero?

          title = title_with_ids[:title]
          params = {
            title: title,
            gameId: GAME_ID_CS,
            period: '1M'
          }

          history_values = dmarket_account.trade_aggregator(params)
          avg = average_from_history_values(history_values).round(2)
          next if avg.zero?

          mp_dollar = (best_offer / DOLLAR_TO_RUB).round(2)
          equation = avg / mp_dollar

          puts "EQUATION: #{equation}"
          if equation > 1.1
            existing_data = File.exist?(FILE_PATH) ? JSON.parse(File.read(FILE_PATH)) : {}

            dmarket_link = "https://dmarket.com/ru/ingame-items/item-list/csgo-skins?title=#{title}"
            market_link = "https://market-old.csgo.com/item/#{title_with_ids[:class_id]}-#{title_with_ids[:instance_id]}"
            price_to_buy = (best_offer * 100) + 5
            buy_link = "https://market.csgo.com/api/v2/buy?key=#{market_api}&hash_name=#{title}&price=#{price_to_buy}"

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
                  link: market_link,
                  buy_link: buy_link
                }
              }
            }

            updated_data = existing_data.merge(data)

            File.write(FILE_PATH, JSON.pretty_generate(updated_data))
          end
        end
      end
    end
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
    prices = history_values[:avgPrice].map do |e|
      next if e.empty?

      price_in_cents = e.to_f
    end.compact

    return 0 if prices.empty? || prices.count < 16

    sorted_prices = prices.sort
    without_gap_prices =  prices.count > 20 ? sorted_prices[0...-18] : sorted_prices[0...-13]
    without_gap_prices.sum / without_gap_prices.size
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

  def build_list
    market_account.client.prices_rub_c_i.body[:items].select do |key, row|
      excluded = EXCLUDED_TITLES.detect { |e| row[:market_hash_name].match(e) }

      row[:price].to_f > 100 && row[:price].to_f < 11000  && !excluded
    end
  end
end
