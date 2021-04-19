require 'ed25519'

module Bot
  module SignatureBuilder

    API_URL = 'https://api.dmarket.com'

    private

    def timestamp
      Time.now.to_i.to_s
    end

    def unsign
      request_method + request_url + request_body + timestamp
    end

    def signing_key
      str_32_bytes = private_key.scan(/../).map { |x| x.hex.chr }.join

      Ed25519::SigningKey.new(str_32_bytes)
    end

    def signature
      signature = signing_key.sign unsign
      signature_to_hex = signature.bytes.pack("c*").unpack("H*").first
      "dmar ed25519 " + signature_to_hex
    end

    def headers
      # Get headers for request, this always has same keys.
      { "X-Api-Key" => public_key,
        "X-Request-Sign" => signature,
        "X-Sign-Date" => timestamp,
        "Content-Type" => "application/json",
        "Accept" => "application/json" }
    end

    def dmarket_url
      API_URL + request_url
    end
  end
end
