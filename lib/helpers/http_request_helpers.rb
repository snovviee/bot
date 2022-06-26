module Bot
  module HttpRequestHelpers

    private

    def get(url, headers = nil, timeout: 10)
      HTTParty.get(url, headers: headers, timeout: timeout)
    rescue Net::OpenTimeout, Net::ReadTimeout, SocketError,
           OpenSSL::SSL::SSLError, Errno::EPIPE, Errno::ECONNRESET
      retry
    end

    def post(url, body, headers, timeout = nil)
      HTTParty.post(url, body: body, headers: headers, timeout: timeout)
    end

    def patch(url, body, headers)
      HTTParty.patch(url, body: body, headers: headers)
    end
  end
end
