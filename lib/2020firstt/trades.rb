require_relative '../market'

module Bot
  class Trades < Market

    def searching_key
      '4Tr98vP6aC038bU031bj68ty378T5Jh'
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
