require_relative '../market'

module Bot
  class Trades < Market

    def searching_key
      'Gpil76d5MnIF243Klyl8PaSV5T894xT'
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
