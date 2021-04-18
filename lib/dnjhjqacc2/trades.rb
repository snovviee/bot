require_relative '../market'

module Bot
  class Trades < Market

    def searching_key
      '8Z5i856eM8t0d79c1d0m8L2oI0u8NWY'
    end

    private
    ###########################################################################

    def min_percent
      1.4
    end

    def max_percent
      1.9
    end
  end
end
