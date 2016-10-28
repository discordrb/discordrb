module Discordrb::RPC
  # Represents a cycle of one RPC request to its response.
  class FrameCycle
    # Creates a new frame cycle.
    # @param nonce [String] The nonce to uniquely identify this cycle.
    def initialize(nonce)
      @nonce = nonce
    end
  end
end
