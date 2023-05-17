module MarketAccount
  module Settings
    FILE_SETTINGS_PATH = 'config/order_settings.json'

    private

    def settings
      json_data = File.read(FILE_SETTINGS_PATH)
      JSON.parse(json_data, symbolize_names: true)
    end

    def remove_orders?
      settings[:delete_orders]
    end
  end
end
