require_relative '../market'

module Bot
  class Trades < Market

    def searching_key
      'l2ZrK2f9pQOmpLoYFXyaRK0E78Kf8Xn'
    end

    private
    ###########################################################################

    def min_percent
      1.45
    end

    def max_percent
      1.95
    end
  end
end
