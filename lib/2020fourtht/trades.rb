require_relative '../market'

module Bot
  class Trades < Market

    def searching_key
      'pv5V5Z1ytz3tuwHhymvwycpmco4gwbk'
    end

    private
    ###########################################################################

    def min_percent
      1.25
    end

    def max_percent
      1.75
    end
  end
end
