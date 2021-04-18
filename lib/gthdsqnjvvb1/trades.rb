require_relative '../market'

module Bot
  class Trades < Market

    def searching_key
      '1E745u1v6nfafthSMN0467C7U91ZZL8'
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
