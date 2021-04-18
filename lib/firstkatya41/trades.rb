require_relative '../market'

module Bot
  class Trades < Market

    def searching_key
      'Adu9Ps34GdP1VF1KBdLPM2f2SLxk7TI'
    end

    private
    ###########################################################################

    def min_percent
      1.35
    end

    def max_percent
      1.85
    end
  end
end
