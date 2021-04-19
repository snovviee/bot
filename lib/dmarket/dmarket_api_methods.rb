module Bot
  module DmarketApiMethods

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
      @buy_percent ||= config['buy_percent'].to_f
    end

    def dmarket_user_inventory
      set_dmarket_params '/marketplace-api/v1/user-inventory?BasicFilters.InMarket=true&Presentation=InventoryPresentationDetailed'

      get(dmarket_url, headers)
    end

    def dmarket_withdraw_items
      url = '/exchange/v1/withdraw-assets'
      method = 'POST'
      body = body_for_withdraw
      set_dmarket_params(url, method: method, body: body)

      post(dmarket_url, body, headers)
    end

    def body_for_withdraw
      {
        "assets": [
          {
            "classId": "519977179:4141779296",
            "gameId": "a8db",
            "id": ""
          }
        ],
        "requestId": ""
      }.to_json
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
