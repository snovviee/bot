require_relative 'sending_items'

module Bot
  class AcceptingItems < SendingItems

    def start_accepting
      while true
        begin
          logged.get_trade_offers['trade_offers_received'].each do |offer|
            next unless offer['message'].size == 36

            logged.accept_trade_offer(offer['tradeofferid'])
            sleep(1)
          end
        rescue
          sleep(10)
          retry
        end

        sleep(30)
      end
    end
  end
end
