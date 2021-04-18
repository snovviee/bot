require_relative '../market'

module Bot
  class Trades < Market

    def searching_key
      'cOGir606v2mRQN4bMcz6Dpx9d441uoH'
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
