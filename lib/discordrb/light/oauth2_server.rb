require 'webrick'

module Discordrb::Light
  # A utility class that provides a local HTTP server to act as a redirect URI
  # in OAuth2 applications. Useful for RPC, or when you're making a script that
  # wants to do a simple OAuth2-style request in a zeroconf manner.
  class OAuth2Server
    # Creates a new OAuth2 server, without any startup or running being done.
    # @param port [Integer] The port to listen on.
    # @param path [String] The endpoint path to listen on.
    def initialize(port, path = '/')
      @port = port
      @path = path
      @server = WEBrick::HTTPServer.new(Port: port)

      register_endpoint
    end

    # Starts the server, blocking the current thread, without doing any waiting
    # for responses.
    def start
      @server.start
    end

    private

    def register_endpoint
      @server.mount_proc(@path, method(:process_request))
    end

    def process_request(req, res)
      Thread.current[:discordrb_name] ||= 'webrick'

      code = req.query['code']
      Discordrb::LOGGER.debug("OAuth2Server received request with code #{code[0..1]}[redacted]#{code[-2..-1]}")

      res.body = 'Dummy response for Discordrb::Light::OAuth2Server.'
    rescue => e
      Discordrb::LOGGER.log_exception e
    end
  end

  # Represents a token obtained from Discord's token endpoint, with additional
  # functionality for refreshing the token.
  class OAuth2Token
    # The actual token string returned by Discord. This on itself is useless for
    # making requests; the {#token_type} is required as well.
    # @return [String] the token string.
    attr_reader :token

    # The type of the token. Usually 'Bearer'.
    # @return [String] the token type.
    attr_reader :token_type

    # @return [Integer] the total lifetime of the token, in seconds.
    attr_reader :lifetime

    # Create a new token from data received from Discord's token endpoint.
    # @param data [Hash] The data this token should represent.
    def initialize(data)
      @token = data['access_token']
      @token_type = data['token_type']
      @lifetime = data['expires_in']
      @refresh_token = data['refresh_token']
      @scope = data['scope'].split(' ').map(&:to_sym)
    end
  end
end
