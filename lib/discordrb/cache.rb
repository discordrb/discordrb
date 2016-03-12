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

    # Gets a channel given its ID. This queries the internal channel cache, and if the channel doesn't
    # exist in there, it will get the data from Discord.
    # @param id [Integer] The channel ID for which to search for.
    # @return [Channel] The channel identified by the ID.
    def channel(id)
      id = id.resolve_id

      raise Discordrb::Errors::NoPermission if @restricted_channels.include? id

      debug("Obtaining data for channel with id #{id}")
      return @channels[id] if @channels[id]

      begin
        response = API.channel(token, id)
        channel = Channel.new(JSON.parse(response), self)
        @channels[id] = channel
      rescue Discordrb::Errors::NoPermission
        debug "Tried to get access to restricted channel #{id}, blacklisting it"
        @restricted_channels << id
        raise
      end
    end
  end
end
