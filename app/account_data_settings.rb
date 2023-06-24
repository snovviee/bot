module AccountDataSettings
  class InvalidNick < StandardError
    def message
      'your "NICK" is missing'
    end
  end

  class NotFoundNick < StandardError
    def message
      'need to specify in the ENV "NICK=nick bundle exec ruby app/buy.rb"'
    end
  end

  FILE_SETTINGS_PATH = 'config/account_data.json'

  private

  def settings
    raise NotFoundNick unless nick

    json_data = File.read(FILE_SETTINGS_PATH)
    hash_data = JSON.parse(json_data, symbolize_names: true)
    select_the_account = hash_data[nick.to_sym]
    raise InvalidNick unless select_the_account

    select_the_account
  end

  def nick
    ENV.fetch('NICK', false)
  end

  def market_keys
    settings[:market]
  end

  def dmarket_keys
    settings[:dmarket]
  end

  def steam_keys
    settings[:steam]
  end
end
