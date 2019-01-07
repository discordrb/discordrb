# frozen_string_literal: true

module Discordrb
  # Server emoji
  class Emoji
    include IDObject

    # @return [String] the emoji name
    attr_reader :name

    # @return [Server] the server of this emoji
    attr_reader :server

    # @return [Array<Role>] roles this emoji is active for
    attr_reader :roles

    # @return [true, false] if the emoji is animated
    attr_reader :animated
    alias_method :animated?, :animated

    def initialize(data, bot, server)
      @bot = bot
      @roles = nil

      @name = data['name']
      @server = server
      @id = data['id'].nil? ? nil : data['id'].to_i
      @animated = data['animated']

      process_roles(data['roles']) if server
    end

    # ID or name based comparison
    def ==(other)
      return false unless other.is_a? Emoji
      return Discordrb.id_compare(@id, other) if @id

      name == other.name
    end

    alias_method :eql?, :==

    # @return [String] the layout to mention it (or have it used) in a message
    def mention
      "<#{'a' if animated}:#{name}:#{id}>"
    end

    alias_method :use, :mention
    alias_method :to_s, :mention

    # @return [String] the layout to use this emoji in a reaction
    def to_reaction
      "#{name}:#{id}"
    end

    # @return [String] the icon URL of the emoji
    def icon_url
      API.emoji_icon_url(id)
    end

    # The inspect method is overwritten to give more useful output
    def inspect
      "<Emoji name=#{name} id=#{id} animated=#{animated}>"
    end

    # @!visibility private
    def process_roles(roles)
      @roles = []
      return unless roles

      roles.each do |role_id|
        role = server.role(role_id)
        @roles << role
      end
    end
  end
end
