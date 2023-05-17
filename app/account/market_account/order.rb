require_relative 'base'
require_relative 'settings'
require 'active_support/all'
require 'csv'

module MarketAccount
  class Order < Base
    include Settings

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
    DAY_COUNT = 5

    delegate :delete_orders,
      :get_orders,
      :process_order,
      :prices_rub_c_i,
      :mass_info,
      :itemdb,
      :current_730,
      to: :client

    def build!
      if remove_orders?
        File.open('logs.txt', 'w') do |file|
          file.truncate(0)
        end

        File.open('seats.json', 'w') do |file|
          file.truncate(0)
          file.write(JSON.generate({}))
        end
        response = delete_orders
        if response.success?
          log!("Deleted #{response.body[:deleted_orders]} orders")
        end
      end

      keys = build_list.keys
      log!("Items count: #{keys.size}")
      log!("Start building seats")

      index = 0

      keys.each_slice(100) do |slice|
        response = mass_info_rec(slice)
        results = JSON.parse(response.body, symbolize_names: true)[:results]

        results.each do |result|
          class_id = result[:classid]
          instance_id = result[:instanceid]

          unless result[:history]
            log!("Skip #{class_id}-#{instance_id} due to unavailable history")

            next
          end

          average = calculated_average(result[:history])
          unless average
            # log!("Skip #{class_id}-#{instance_id} due to missing average")

            next
          end

          buy_offers = result[:buy_offers]
          if buy_offers
            price = buy_offers[:best_offer]
          else
            price = average - average * 0.5
            log!("Set #{class_id}-#{instance_id} with custom price. Average: #{average}, Price: #{price}")
          end

          percent = generate_percent(average / 100.0)
          next unless average > price * percent

          price += 1

          response = process_order(class_id, instance_id, price.round)
          puts response.body
          save_seats!(class_id, instance_id, result[:info][:market_hash_name], average, price)
        end

        index += 1
        log!("Iteration #{index} finished")
      end

      log!("Finished building seats")
      data = seats_json
      orders_total = data.map { |k, v| v[:order_price] }.sum
      log!("Built #{data.size} orders with estimated total #{orders_total}")
      rescue => err
        log!("Error: #{err}")
        retry
    end

    def generate_percent(avg)
      case avg
      when 0..5
        percent = 3
      when 5..6
        percent = 2.9
      when 6..9
        percent = 2.8
      when 9..12
        percent = 2.6
      when 12..18
        percent = 2.5
      when 18..22
        percent = 2.4
      when 22..35
        percent = 2.3
      when 35..120
        percent = 2.15
      when 120..320
        percent = 1.8
      when 320..600
        percent = 1.6
      when 600..950
        percent = 1.5
      else
        percent = 1.3
      end
    end

    def buy!
      loop do
        limits = seats_json.transform_values do |value|
          avg = value[:calculated_average]
          percent = generate_percent(avg)

          avg / percent
        end

        current_timestamp = Time.now.to_i

        while (Time.now.to_i - current_timestamp) < 7200 # 2 hours
          current_orders.each_slice(100) do |slice|
            c_i_slice = slice.map { |s| s[:i_classid] + '_' + s[:i_instanceid] }
            response = mass_info_rec(c_i_slice)
            results = JSON.parse(response.body, symbolize_names: true)[:results]
            results.each_slice(5) do |s_results|
              threads = []

              s_results.each do |s_result|
                threads << Thread.new do
                  buy_offers = s_result[:buy_offers]
                  my_offer = buy_offers[:my_offer]
                  best_offer = buy_offers[:best_offer]

                  class_id = s_result[:classid]
                  instance_id = s_result[:instanceid]
                  limit_key = class_id + '_' + instance_id
                  max_offer_limit = (limits[limit_key.to_sym] * 100).round

                  if my_offer < best_offer && (0..max_offer_limit).include?(best_offer)
                    price = best_offer + 1

                    process_order(class_id, instance_id, price.round)
                  end
                end
              end

              threads.each(&:join)
            end
          end
        end
      end
    end

    private

    def seats_json
      json_data = File.read('seats.json')
      JSON.parse(json_data, symbolize_names: true)
    end

    def log!(info)
      File.open('logs.txt', 'a') do |f|
        f.write("#{Time.now}: ")
        f.write(info)
        f.write("\n")
      end
    end

    def current_orders
      response = get_orders
      return response.body[:Orders] if response.success?

      current_orders
    end

    def build_list
      # csv_path = current_730.body[:db]
      # csv_table = itemdb(csv_path).body
      # csv = CSV.parse(csv_table, headers: true, col_sep: ';', converters: :all, header_converters: :symbol)
      # csv.select do |row|
      #   excluded = EXCLUDED_TITLES.detect { |e| row[:c_market_hash_name].match(e) }
      #   row[:c_price] > 300 && !excluded
      # end
      # byebug
      prices_rub_c_i.body[:items].select do |key, row|
        excluded = EXCLUDED_TITLES.detect { |e| row[:market_hash_name].match(e) }

        row[:price].to_f > 3 && !excluded && row[:popularity_7d].to_f > 2
      end
    end

    def five_days_range
      now = Time.now
      past = now - DAY_COUNT.days
      (past.to_i..now.to_i)
    end

    def ten_days_range
      now = Time.now
      past = now - 10.days
      (past.to_i..now.to_i)
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

    def save_seats!(class_id, instance_id, name, average, price)
      data = {
        "#{class_id}_#{instance_id}".to_sym => {
          market_hash_name: name.to_s,
          calculated_average: (average / 100.0).round(2),
          order_price: (price / 100.0).round(2)
        }
      }

      file_path = "seats.json"

      existing_data = File.exist?(file_path) ? JSON.parse(File.read(file_path)) : {}

      updated_data = existing_data.merge(data)

      File.write(file_path, JSON.pretty_generate(updated_data))
    end

    def mass_info_rec(slice, key = nil)
      puts "#{Time.now}: Mass Info Request"
      response = mass_info(slice.join(','), searching_key: key)
      puts "#{Time.now}: Mass Info Response: #{response.code}"
      return response if response.code.to_i == 200

      mass_info_rec(slice)
    end
  end
end
