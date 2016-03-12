module Discordrb
  module Cache
    # Initializes this cache
    def init_cache
      @users = {}

      @servers = {}

      @channels = {}
      @private_channels = {}

      @restricted_channels = []
    end
  end
end
