require_relative 'base'

module MarketAccount
  class Trade < Base
    attr_reader :steam_api_key

    delegate :money_send, :market_inventory, :steam_inventory, :list_items, :best_offer,
             :add_to_sale, :change_currency_to_usd, :bind_steam_api_key, :operation_history,
             :p2p, :balance_v2, :ping_v2, :update_inventory_v2, :remove_all_v2,
             :search_list_items_by_hash_name_all, :set_prices_v2, :trade_check_v2, to: :client

    def trading!
      puts "Handled percent: #{min_percent}"
      puts "Current sum: #{items_sum}"

      remove_all_v2 if removing?
      if allow_money_transfer
        money_send(
          amount: balance_v2.body[:money],
          whom: 'x3FVZ51Ob9CKC3X07f2T94GfAK92PKT',
          pay_password: 'Dvadcat8'
        )
      end

      if change_currency_to_usd?
        remove_all_v2
        change_currency_to_usd
      end

      loop do
        trade_check_v2
        bind_steam_api_key('steam-api-key' => steam_api_key)

        ping_v2

        update_inventory_v2
        add_items_to_sale

        tmp_limits = item_limits

        150.times do
          ping_v2
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

    def change_currency_to_usd?
      ENV.fetch('CHANGE_CURRENCY_TO_USD', false)
    end

    def allow_money_transfer
      ENV.fetch('MONEY_TRANSFER', false)
    end

    def min_percent
      ENV.fetch('MIN_PERCENT', 1.0).to_f
    end

    def max_percent
      min_percent + 0.5
    end

    def items_sum
      return 0 if items.empty?

      items.map { |e| e[:price] }.sum
    end

    def add_items_to_sale(cur: 'USD', price: 9999999)
      steam_inventory.body[:items].each_slice(5) do |s_items|
        threads = []

        s_items.each do |item|
          threads << Thread.new do
            add_to_sale(id: item[:id], price: price, cur: cur)
          end
        end

        threads.each(&:join)
        sleep(1)
      end

    rescue NoMethodError
      puts 'Trying to refetch'

      update_inventory_v2
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

          # new_market_hash_name = market_hash_name
          # if result[market_hash_name]
          #   unless result[:class_id] == item[:classid].to_i && result[:instance_id] == item[:instanceid].to_i
          #     new_market_hash_name = market_hash_name + "_" + item[:classid] + "_" + item[:instanceid]
          #   end
          # end
          # next if result[new_market_hash_name]

          result[market_hash_name] = {
            # class_id: item[:classid].to_i,
            # instance_id: item[:instanceid].to_i,
            min: averages[market_hash_name.to_sym][:average] * min_percent,
            max: averages[market_hash_name.to_sym][:average] * max_percent,
            price: 6999999,
            id: item[:item_id]
          }
        end
      end

      result
    end

    def items
      response = market_inventory
      if response.success?
        response.body[:items] || []
      else
        []
      end
    end

    def change_price(limits)
      limits.each_slice(10) do |s_limits|
        ping_v2
        item_titles = s_limits.map { |el| el[0] }
        response = get_list_items(item_titles)
        next unless response

        results = JSON.parse(response.body, symbolize_names: true)[:data]
        threads = []

        s_limits.each do |name, limit|
          select_item = results[name.to_sym]
          item_prices = select_item.map { |i| i[:price].to_f / 1000 }

          threads << Thread.new do
            offer = item_prices.min
            next if offer == limit[:price] && offer <= limit[:max]

            limit[:price] = correct_price(offer, limit, item_prices)
            set_prices_v2(limit[:id], (limit[:price] * 1000).round)
          end
        end

        threads.each(&:join)
      end
    rescue => err
      puts err
      retry
    end

    def get_list_items(item_titles)
      response = search_list_items_by_hash_name_all(item_titles)
      unless response.kind_of? Net::HTTPSuccess
        5.times do
          sleep 0.5
          response = search_list_items_by_hash_name_all(item_titles)
          return response if response.kind_of? Net::HTTPSuccess
        end
      end

      response if response.kind_of? Net::HTTPSuccess
    end

    def correct_price(offer, limit, item_prices)
      min = limit[:min]
      max = limit[:max]
      price = offer - 0.001
      if limit[:price] + 0.01 < offer || !(min..max).include?(price)
        # all prices may be less than the min threshold, then set the max. lol
        return item_prices.detect { |i_price| i_price >= min } || max - 0.001
      end

      price
    end
  end
end
