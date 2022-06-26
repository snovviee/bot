require_relative '../market/market_api_methods'

module Bot
  module RedefinedMarketApiMethods
    include MarketApiMethods

    SEARCHING_API_KEY = '36aE1oXFB3hMDU30Q2PdZ5K7qjb1w12'

    private

    def get_average_for(title)
      url = "https://market.csgo.com/api/v2/get-list-items-info?key="\
            "#{SEARCHING_API_KEY}&list_hash_name[]=#{URI.encode(title)}"
      data = get(url)['data']
      return unless data.any?

      avg = to_dollar(data[title]['average'])

      prices = data[title]['history'].map { |el| el.last }
      return if prices.detect { |el| el > avg * 5 }

      avg
    rescue NoMethodError
      retry
    end

    def to_dollar(rub)
      rub / currency * 100
    end

    def currency
      74
    end

    def all_market_items
      url = "https://market.csgo.com/api/v2/prices/USD.json"
      # 'market_hash_name', 'price' keys
      @market_items ||= get(url)['items'].select do |item|
        !item['market_hash_name'][/(?:Case|Sticker|Souvenir|Death\sSentence|Capsule|Prof\.|\sSabre|Graffiti|McCoy|Name\sTag|Patch)/] &&
          item['price'].to_f < 2
      end
    end
  end
end
