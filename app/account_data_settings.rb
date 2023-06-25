module AccountDataSettings
  class InvalidNick < StandardError
    def initialize(nick)
      @nick = nick
    end

    def message
      "your #{@nick} is invalid"
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
    @settings ||= begin
      raise NotFoundNick unless nick

      file_data.tap { |d| raise InvalidNick.new(nick) unless d[nick] }[nick]
    end
  end

  def file_data
    json_data = File.read(FILE_SETTINGS_PATH)
    JSON.parse(json_data, symbolize_names: true)
  end

  def nick
    ENV.fetch('NICK', nil)&.to_sym
  end
end
