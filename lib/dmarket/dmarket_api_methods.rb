module Bot
  module DmarketApiMethods

    SEARCHING_API_KEY = '36aE1oXFB3hMDU30Q2PdZ5K7qjb1w12'

    private

    def get_dmarket_offers(avg)
      begin
        url = "/exchange/v1/offers-by-title?Title=#{URI.encode(title)}&Limit=100"
        set_dmarket_params(url)

        objects = get(dmarket_url, headers)['objects']
        return [] unless objects

        objects.reject! {|a| a['title'].include?('Souvenir') } if objects.any?
        objects
      rescue Errno::ECONNRESET
        objects = []
      end

      return [] unless objects.any?

      buyable_objects = objects.select do |el|
        avg && avg > (el['price']['USD'].to_f * buy_percent) &&
          el['inMarket'] == true
      end
      return [] unless buyable_objects.any?

      buyable_objects.map do |el|
        { offerId: el['extra']['offerId'], price: el['price']['USD'] }
      end
    end

    def an_dmarket_offer(avg)
      url = "/exchange/v1/offers-by-title?Title=#{URI.encode(title)}&Limit=100"
      set_dmarket_params(url)

      objects = get(dmarket_url, headers)['objects']
      return unless objects

      a = objects.select { |el| avg > el['price']['USD'].to_f }

      a.map { |el| el['price']['USD'].to_f }.sort.first
    end

    def set_dmarket_params(url, method: 'GET', body: '')
      self.request_method = method
      self.request_url = url
      self.request_body = body
    end

    def dmarket_balance
      set_dmarket_params '/account/v1/balance'

      get(dmarket_url, headers)['usd'].to_f / 100
    end

    def buy_percent
      @buy_percent ||= config['BuyPercent'].to_f
    end

    def dmarket_user_inventory
      set_dmarket_params "/marketplace-api/v1/user-inventory?GameID=a8db&BasicFilters.InMarket=true&Presentation=InventoryPresentationDetailed&Limit=500"

      get(dmarket_url, headers)
    end

    def dmarket_withdraw_items
      url = '/exchange/v1/withdraw-assets'
      method = 'POST'
      body = body_for_withdraw
      set_dmarket_params(url, method: method, body: body)

      post(dmarket_url, body, headers)
    end

    def update_dmarket_inventory
      url = '/marketplace-api/v1/user-inventory/sync'
      body = { 'Type': 'Inventory', 'GameID': 'CSGO' }.to_json
      method = 'POST'
      set_dmarket_params(url, method: method, body: body)

      post(dmarket_url, body, headers)
    end

    def process_withdrawing
      update_dmarket_inventory
      response = dmarket_user_inventory

      response['Items'].each do |item|
        @id = item['AssetID']
        @class_id = item['ClassID']
        @request_id = item['Attributes'].detect { |el| el['Name'] == 'linkId' }['Value']
        p dmarket_withdraw_items
        sleep(8)
      end
    end

    def body_for_withdraw
      { "assets": [ { "classId": "#{@class_id}", "gameId": "a8db", "id": "#{@id}" } ],
      "requestId": "#{@request_id}" }.to_json
    end

    def dmarket_buy(offers)
      return [] unless offers.any?

      url = "/exchange/v1/offers-buy"
      method = 'PATCH'
      offers[0..5].map do |offer|
        body = body_offers(offer[:offerId], offer[:price])
        set_dmarket_params(url, method: method, body: body)

        patch(dmarket_url, body, headers)['status']
      end

      p dmarket_balance
    end

    def aggregated_prices
      url = "/price-aggregator/v1/aggregated-prices"
      set_dmarket_params(url)
      csgo_items = get(dmarket_url, headers)['AggregatedTitles'].select { |item| item['GameID'] == 'a8db' }

      middle_items = csgo_items.select { |item| item['Offers']['BestPrice'].to_f > 2 && item['Offers']['BestPrice'].to_f <= 5 && item['MarketHashName'][/\A\'/].nil? }

      low_items = csgo_items.select { |item| item['Offers']['BestPrice'].to_f <= 2 && item['MarketHashName'][/\A\'/].nil? }

      high_items = csgo_items.select { |item| item['Offers']['BestPrice'].to_f > 5 && item['Offers']['BestPrice'].to_f <= 100 && item['MarketHashName'][/\A\'/].nil? }

      super_items = csgo_items.select { |item| item['Offers']['BestPrice'].to_f > 100 && item['MarketHashName'][/\A\'/].nil? }

      handle_items(low_items)
      byebug
    end

    def handle_items(expensive_items)
      profit = 0
      cost = 0
      index = 0

      expensive_items.each do |item|
        name = item['MarketHashName']
        byebug if name == 'Cache Pin'
        dm_price = item['Offers']['BestPrice'].to_f
        if dm_price.zero?
          puts "NOT FOUND #{name}"

          next
        end

        market_price = current_market_price(name)
        unless market_price
          puts "ERROR #{name}"

          next
        end
        diff = (market_price - dm_price).round(2)
        next if diff < 0

        puts "#{name}: #{dm_price} - #{market_price}, diff: #{diff}\n"
        profit += diff
        cost += dm_price
        index += 1
      end

      byebug
    end

    def current_market_price(name)
      value = get_list_items_info(name)['data'][name]['average'] / 73
      value.round(2)
    # rescue NoMethodError
    #   retry
    rescue
      byebug
    end

    def get_list_items_info(name)
      url = "https://market.csgo.com/api/v2/get-list-items-info?key="\
            "#{SEARCHING_API_KEY}&list_hash_name[]=#{URI.encode(name)}"
      get(url)
    end

    def dmarket_user_info
      set_dmarket_params '/account/v1/user'

      get(dmarket_url, headers)
    end

    def body_offers(offerId, price)
      { "offers": [
        {
          "offerId": "#{offerId}",
          "price": {
            "amount": "#{price}",
            "currency": "USD"
          },
          "type": "dmarket"
        }
      ]}.to_json
    end

    def process_buy_items
      all_market_items.each do |item|
        self.title = item['market_hash_name']
        average = get_average_for title

        offers = get_dmarket_offers(average)
        dmarket_buy(offers)
      end
    end

    def process_test_prices
      a = an_market_items.map do |item|
        self.title = item['market_hash_name']
        average = market_list_info_avg
        next unless average

        best_offer = an_dmarket_offer(average)
        next unless best_offer

        "#{(average/100).round(2)}, #{best_offer/100}, #{title}"
      end

      File.open('output.txt', 'w') { |file| a.each { |el| file.puts(el) } }
    end
  end
end
