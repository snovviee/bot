module Bot
  module HttpRequestHelpers

    private

    def get(url, headers = nil)
      HTTParty.get(url, headers: headers)
    rescue Net::OpenTimeout, Net::ReadTimeout, SocketError,
           OpenSSL::SSL::SSLError
      retry
    end

    def post(url, body, headers)
      HTTParty.post(url, body: body, headers: headers)
    end

    def patch(url, body, headers)
      HTTParty.patch(url, body: body, headers: headers)
    end
  end
end
