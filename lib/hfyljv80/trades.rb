require_relative '../market'

module Bot
  class Trades < Market

    def searching_key
      'q7pz1Ci756Us9YOtepygit3wC9GgVIm'
    end

    private
    ###########################################################################

    def min_percent
      0.9
    end

    def max_percent
      1.4
    end
  end
end
