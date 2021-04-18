require_relative '../market'

module Bot
  class Trades < Market

    def searching_key
      '0Lr65Ufx4T5A8Z345sqkDoiwLCaPYhS'
    end

    private
    ###########################################################################

    def min_percent
      1.3
    end

    def max_percent
      1.8
    end
  end
end
