module Bot
  module MarketApiMethods

    PAY_PASSWORD = 'Dvadcat8'
    KEY_TO_GET_MONEY = '5c5g5ctetdoB7029NmvoF0NnXtDyneF'

    private

    def ping
      get request('api/PingPong/direct')
    end

    def update_inventory
      get request('api/UpdateInventory')
    end

    def add_items_to_sale
      get_items('my-inventory').each { |item| add_to_sale(item['id']) }
    rescue NoMethodError
      retry
    end

    def change_item_price_with(limits)
      limits.each do |values|
        classid, instanceid = values[:classid], values[:instanceid]

        values[:best_offer] = get_best_offer(classid, instanceid)
        next if values[:price] == values[:best_offer]

        values[:price] = correct_price_with(values)
        set_price_with values
      end
    end

    def set_price_with(values)
      price = (values[:price] * 100).round
      req = request("api/MassSetPrice/#{values[:classid]}_#{values[:instanceid]}/#{price}")
      get req
    end

    def correct_price_with(values)
      max = values[:max]
      return max if values[:best_offer].zero?

      price = values[:best_offer] - 0.01
      price = max unless (values[:min]..max).include?(price)
      price
    end

    def market_balance
      get(request('api/GetMoney'))['money']
    end

    def current_balance
      p "Current balance: #{get(request('api/GetMoney'))['money'] * 0.01} RUB"
    rescue NoMethodError
      byebug
    end

    def p2p_request
      get request('api/v2/trade-request-give-p2p-all')
    end

    def get_best_offer(classid, instanceid)
      url = "https://market.csgo.com/api/BestSellOffer/#{classid}_"\
            "#{instanceid}/?key=#{searching_api_key}"
      get(url)['best_offer'].to_f * 0.01
    end

    def remove_items_from_trade
      get request('api/RemoveAll')
    end

    def money_send
      url = "https://market.csgo.com/api/v2/money-send/"\
            "#{get(request('api/GetMoney'))['money']}/"\
            "#{KEY_TO_GET_MONEY}?pay_pass=#{PAY_PASSWORD}&"\
            "key=#{market_api_key}"
      get url
    end

    def set_pay_password
      url = "https://market.csgo.com/api/v2/set-pay-password?"\
            "new_password=#{PAY_PASSWORD}&key=#{market_api_key}"
      get url
    end

    def market_items
      get_items('items')
    end

    def get_item_limits
      items = market_items.uniq { |i| i['classid'] && i['market_hash_name'] }

      items.each_with_object([]) do |market_item, limits|
        average = get_average_for market_item['market_hash_name']

        limits << { classid: market_item['classid'].to_i,
                    instanceid: market_item['instanceid'].to_i,
                    min: average * minimum_percent,
                    max: average * maximum_percent,
                    price: 666666 }
      end
    rescue NoMethodError
      retry
    end

    def get_average_for(title)
      url = "https://market.csgo.com/api/v2/get-list-items-info?key="\
            "#{searching_api_key}&list_hash_name[]=#{URI.encode(title)}"
      get(url)['data'][title]['average']
    rescue NoMethodError
      retry
    end

    def request(path, optional: '')
      "https://market.csgo.com/#{path}/?key=#{market_api_key}#{optional}"
    end

    def get_items(items_type)
      get(request("api/v2/#{items_type}"))['items']
    end

    def add_to_sale(item_id)
      optional = "&id=#{item_id}&price=999999999&cur=RUB"
      get request("api/v2/add-to-sale", optional: optional)
    end
  end
end
