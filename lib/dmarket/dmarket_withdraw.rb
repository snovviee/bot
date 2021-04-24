require_relative 'dmarket_api'

module Bot
  class DmarketWithdraw < DmarketTrading

    def start_withdraw
      process_withdrawing
    end
  end
end
