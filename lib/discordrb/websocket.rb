require 'websocket-client-simple'

module Discordrb
  # Utility wrapper class that abstracts an instance of WSCS. Useful should we decide that WSCS isn't good either -
  # in that case we can just switch to something else
  class WebSocket
    def initialize(endpoint)
      @client = WebSocket::Client::Simple.connect(endpoint)
    end
  end
end