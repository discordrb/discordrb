# frozen_string_literal: true

module Discordrb
  # Voice regions are the locations of servers that handle voice communication in Discord
  class VoiceRegion
    # @return [String] unique ID for the region
    attr_reader :id
    alias_method :to_s, :id

    # @return [String] name of the region
    attr_reader :name

    # @return [String] an example hostname for the region
    attr_reader :sample_hostname

    # @return [Integer] an example port for the region
    attr_reader :sample_port

    # @return [true, false] if this is a VIP-only server
    attr_reader :vip

    # @return [true, false] if this voice server is the closest to the client
    attr_reader :optimal

    # @return [true, false] whether this is a deprecated voice region (avoid switching to these)
    attr_reader :deprecated

    # @return [true, false] whether this is a custom voice region (used for events/etc)
    attr_reader :custom

    def initialize(data)
      @id = data['id']

      @name = data['name']

      @sample_hostname = data['sample_hostname']
      @sample_port = data['sample_port']

      @vip = data['vip']
      @optimal = data['optimal']
      @deprecated = data['deprecated']
      @custom = data['custom']
    end
  end
end
