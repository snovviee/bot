require_relative '../market'

module Bot
  class Trades < Market

    def searching_key
      'H0U4uj28oAhRg0IcTSGVhX1sOnGj3au'
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
