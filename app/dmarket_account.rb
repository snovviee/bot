require 'dmarket_api'
require 'active_support/core_ext/module/delegation'

class DmarketAccount
  attr_reader :client

  GAME_ID = 'a8db'
  EXCLUDED_TITLES = [
    'Sticker',
    'Souvenir',
    'Case',
    'Name Tag',
    'Capsule',
    'Sealed Graffiti',
    'RMR',
    'Patch',
    'Ground Rebel'
  ]

  def initialize(options = {})
    @client = DmarketApi::Client.new(
      api_key: options[:api_key],
      secret_key: options[:secret_key]
    )
  end

  delegate :inventory_sync, :buy, :title_offers, :withdraw, :balance, :inventory, to: :client

  def get_items_into_file!(cursor = nil)
    params = {
      currency: 'USD',
      limit: '100',
      gameid: GAME_ID,
      inMarket: true,
      priceTo: 200
    }

    params.merge!(cursor: cursor) if cursor

    response = client.items(params)
    if response.success?
      cursor = response.body[:cursor]

      File.open("items.txt", "a") do |f|
        response.body[:objects].each do |obj|
          next if EXCLUDED_TITLES.detect { |e| obj[:title].match(e) }

          f.write(obj[:title])
          f.write("\n")
        end
      end
    end
    return if cursor.nil? || cursor.empty?

    get_items_into_file!(cursor)
  end

  def withdraw!
    inventory_sync(Type: 'Inventory', GameID: 'CSGO')
    items.each do |item|
      body = {
        assets: [
          {
            classId: item[:ClassID],
            gameId: GAME_ID,
            id: item[:AssetID]
          }
        ],
        requestId: item[:Attributes].detect { |e| e[:Name] == 'linkId' }[:Value]
      }

      withdraw(body)
      inventory_sync(Type: 'Inventory', GameID: 'CSGO')

      sleep(20)
    end
  end

  private

  def items
    response = inventory(
      GameID: GAME_ID,
      Presentation: 'InventoryPresentationDetailed',
      Limit: 500,
      'BasicFilters.InMarket'.to_sym => true
    )

    if response.success?
      response.body[:Items]
    end
  end
end
