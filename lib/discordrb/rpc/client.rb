module Discordrb::RPC
  # Client for Discord's RPC protocol.
  class Client
    def initialize(client_id, origin)
      @client_id = client_id
      @origin = origin
    end
  end
end
