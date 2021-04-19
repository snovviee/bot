module Bot
  module AccountConfig

    def account_config
      JSON.parse File.read('config.json')
    end
  end
end
