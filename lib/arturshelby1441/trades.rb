require_relative '../market'

module Bot
  class Trades < Market

    def searching_key
      'y7anV6S8421rHD5GpH1zJ112g6h16f3'
    end

    private
    ###########################################################################

    def min_percent
      1.5
    end

    def max_percent
      2
    end
  end
end
