# frozen_string_literal: true

module Discordrb
  # Mixin for objects that have IDs
  module IDObject
    # @return [Integer] the ID which uniquely identifies this object across Discord.
    attr_reader :id
    alias_method :resolve_id, :id
    alias_method :hash, :id

    # ID based comparison
    def ==(other)
      Discordrb.id_compare(@id, other)
    end

    alias_method :eql?, :==

    # Estimates the time this object was generated on based on the beginning of the ID. This is fairly accurate but
    # shouldn't be relied on as Discord might change its algorithm at any time
    # @return [Time] when this object was created at
    def creation_time
      # Milliseconds
      ms = (@id >> 22) + DISCORD_EPOCH
      Time.at(ms / 1000.0)
    end

    # Creates an artificial snowflake at the given point in time. Useful for comparing against.
    # @param time [Time] The time the snowflake should represent.
    # @return [Integer] a snowflake with the timestamp data as the given time
    def self.synthesise(time)
      ms = (time.to_f * 1000).to_i
      (ms - DISCORD_EPOCH) << 22
    end

    class << self
      alias_method :synthesize, :synthesise
    end
  end
end
