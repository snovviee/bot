require 'thread/pool'
require_relative './bot_helpers'

module Bot
  class Market
    include BotHelpers

    def initialize(market_api_key)
      @market_api_key = market_api_key
    end

    def market_api_key
      @market_api_key
    end

    def searching_key
      # Should be redefine in child.
    end

    def start
      threading_trading
    end

    private
    ###########################################################################

    def get_items(items_type)
      url = "https://market.csgo.com/api/v2/#{items_type}?key="\
            "#{market_api_key}"
      get_value(url, 'items')
    end

    def add_to_sale(item_id)
      url = "https://market.csgo.com/api/v2/add-to-sale?"\
            "key=#{market_api_key}&id=#{item_id}&price=999999999&cur=RUB"
      get(url)
    end

    def get_best_offer(classid, instanceid)
      url = "https://market.csgo.com/api/BestSellOffer/#{classid}_"\
            "#{instanceid}/?key=#{searching_key}"
      # Api request returns a string in cents.
      get_value(url, 'best_offer').to_f * 0.01
    end

    def limits
      prev_class_id, prev_instance_id = nil, nil

      items = get_items('items').sort_by { |item| item['market_hash_name'] }
      items.each_with_object([]) do |market_item, limits|
        begin
        item_name = market_item['market_hash_name']
        class_id = market_item['classid'].to_i
        instance_id = market_item['instanceid'].to_i
        next if class_id == prev_class_id && instance_id == prev_instance_id

        for_each_step do
          average = get_average(item_name)
          limits << { classid: class_id,
                      instanceid: instance_id,
                      min: average * min_percent,
                      max: average * max_percent,
                      price: 666666 }
        end

        prev_class_id, prev_instance_id = class_id, instance_id
      rescue => error
        byebug
      end
      end.uniq
    end

    def set_price(values)
      price = (values[:price] * 100).round
      url = "https://market.csgo.com/api/MassSetPrice/#{values[:classid]}"\
            "_#{values[:instanceid]}/#{price}/?key=#{market_api_key}"
      get(url)
    end

    def get_average(item_name)
      fixed_name = scrub_item_name(item_name)
      url = "https://market.csgo.com/api/v2/get-list-items-info?key="\
            "#{searching_key}&list_hash_name[]=#{fixed_name}"
      get_value(url, 'data')[item_name]['average']
    end

    def correct_price(values)
      max = values[:max]
      return max if values[:best_offer].zero?

      price = values[:best_offer] - 0.01
      price = max unless (values[:min]..max).include?(price)
      price
    end

    def scrub_item_name(item_name)
      item_name.gsub("™", "#{URI.encode('™')}")
    end

    def min_percent
      1.3
    end

    def max_percent
      1.8
    end

    def for_each_step(&block)
      begin
        yield

      rescue JSON::ParserError
        retry
      end
    end

    def change_price(limits, x, y)
      limits[x..y].each do |values|
        classid, instanceid = values[:classid], values[:instanceid]

        for_each_step do
          values[:best_offer] = get_best_offer(classid, instanceid)
          next if values[:price] == values[:best_offer]

          values[:price] = correct_price(values)
          set_price(values)
          p values
        end
      end
    end

    def threading_trading
      threads = []

      loop do
        ping
        update_inventory
        add_items
        tmp_limits = limits
        limits_count = tmp_limits.count
        p 'Limits was got.'

        300.times do |index|
          threads << Thread.new do
            change_price(tmp_limits, 0, limits_count/2)
          end

          threads << Thread.new do
            change_price(tmp_limits, limits_count/2, limits_count)
          end

          threads << Thread.new do
            ping
            sleep(180)
          end

          threads.each { |thr| thr.join }
        end
      end
    rescue
      retry
    end

    def ping
      url = "https://market.csgo.com/api/PingPong/direct/?key="\
            "#{market_api_key}"
      p "Ping status: #{get_value(url, 'success')}."
    rescue JSON::ParserError
      retry
    end

    def update_inventory
      url = "https://market.csgo.com/api/UpdateInventory/?key="\
            "#{market_api_key}"
      p "Inventory status: #{get_value(url, 'success')}."
    rescue JSON::ParserError
      retry
    end

    def add_items
      get_items('my-inventory').each { |item| add_to_sale(item['id']) }
      p 'Items was added.'
    end
  end
end
