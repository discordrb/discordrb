# frozen_string_literal: true

module Discordrb
  # A Discord role that contains permissions and applies to certain users
  class Role
    include IDObject

    # @return [Permissions] this role's permissions.
    attr_reader :permissions

    # @return [String] this role's name ("new role" if it hasn't been changed)
    attr_reader :name

    # @return [Server] the server this role belongs to
    attr_reader :server

    # @return [true, false] whether or not this role should be displayed separately from other users
    attr_reader :hoist

    # @return [true, false] whether or not this role is managed by an integration or a bot
    attr_reader :managed
    alias_method :managed?, :managed

    # @return [true, false] whether this role can be mentioned using a role mention
    attr_reader :mentionable
    alias_method :mentionable?, :mentionable

    # @return [ColourRGB] the role colour
    attr_reader :colour
    alias_method :color, :colour

    # @return [Integer] the position of this role in the hierarchy
    attr_reader :position

    # This class is used internally as a wrapper to a Role object that allows easy writing of permission data.
    class RoleWriter
      # @!visibility private
      def initialize(role, token)
        @role = role
        @token = token
      end

      # Write the specified permission data to the role, without updating the permission cache
      # @param bits [Integer] The packed permissions to write.
      def write(bits)
        @role.send(:packed=, bits, false)
      end

      # The inspect method is overridden, in this case to prevent the token being leaked
      def inspect
        "<RoleWriter role=#{@role} token=...>"
      end
    end

    # @!visibility private
    def initialize(data, bot, server = nil)
      @bot = bot
      @server = server
      @permissions = Permissions.new(data['permissions'], RoleWriter.new(self, @bot.token))
      @name = data['name']
      @id = data['id'].to_i

      @position = data['position']

      @hoist = data['hoist']
      @mentionable = data['mentionable']
      @managed = data['managed']

      @colour = ColourRGB.new(data['color'])
    end

    # @return [String] a string that will mention this role, if it is mentionable.
    def mention
      "<@&#{@id}>"
    end

    # @return [Array<Member>] an array of members who have this role.
    # @note This requests a member chunk if it hasn't for the server before, which may be slow initially
    def members
      @server.members.select { |m| m.role? self }
    end

    alias_method :users, :members

    # Updates the data cache from another Role object
    # @note For internal use only
    # @!visibility private
    def update_from(other)
      @permissions = other.permissions
      @name = other.name
      @hoist = other.hoist
      @colour = other.colour
      @position = other.position
      @managed = other.managed
    end

    # Updates the data cache from a hash containing data
    # @note For internal use only
    # @!visibility private
    def update_data(new_data)
      @name = new_data[:name] || new_data['name'] || @name
      @hoist = new_data['hoist'] unless new_data['hoist'].nil?
      @hoist = new_data[:hoist] unless new_data[:hoist].nil?
      @colour = new_data[:colour] || (new_data['color'] ? ColourRGB.new(new_data['color']) : @colour)
    end

    # Sets the role name to something new
    # @param name [String] The name that should be set
    def name=(name)
      update_role_data(name: name)
    end

    # Changes whether or not this role is displayed at the top of the user list
    # @param hoist [true, false] The value it should be changed to
    def hoist=(hoist)
      update_role_data(hoist: hoist)
    end

    # Changes whether or not this role can be mentioned
    # @param mentionable [true, false] The value it should be changed to
    def mentionable=(mentionable)
      update_role_data(mentionable: mentionable)
    end

    # Sets the role colour to something new
    # @param colour [ColourRGB] The new colour
    def colour=(colour)
      update_role_data(colour: colour)
    end

    alias_method :color=, :colour=

    # Changes this role's permissions to a fixed bitfield. This allows setting multiple permissions at once with just
    # one API call.
    #
    # Information on how this bitfield is structured can be found at
    # https://discord.com/developers/docs/topics/permissions.
    # @example Remove all permissions from a role
    #   role.packed = 0
    # @param packed [Integer] A bitfield with the desired permissions value.
    # @param update_perms [true, false] Whether the internal data should also be updated. This should always be true
    #   when calling externally.
    def packed=(packed, update_perms = true)
      update_role_data(permissions: packed)
      @permissions.bits = packed if update_perms
    end

    # Moves this role above another role in the list.
    # @param other [Role, String, Integer, nil] The role, or its ID, above which this role should be moved. If it is `nil`,
    #   the role will be moved above the @everyone role.
    # @return [Integer] the new position of this role
    def sort_above(other = nil)
      other = @server.role(other.resolve_id) if other
      roles = @server.roles.sort_by(&:position)
      roles.delete_at(@position)

      index = other ? roles.index { |role| role.id == other.id } + 1 : 1
      roles.insert(index, self)

      updated_roles = roles.map.with_index { |role, position| { id: role.id, position: position } }
      @server.update_role_positions(updated_roles)
      index
    end

    alias_method :move_above, :sort_above

    # Deletes this role. This cannot be undone without recreating the role!
    # @param reason [String] the reason for this role's deletion
    def delete(reason = nil)
      API::Server.delete_role(@bot.token, @server.id, @id, reason)
      @server.delete_role(@id)
    end

    # The inspect method is overwritten to give more useful output
    def inspect
      "<Role name=#{@name} permissions=#{@permissions.inspect} hoist=#{@hoist} colour=#{@colour.inspect} server=#{@server.inspect} position=#{@position} mentionable=#{@mentionable}>"
    end

    private

    def update_role_data(new_data)
      API::Server.update_role(@bot.token, @server.id, @id,
                              new_data[:name] || @name,
                              (new_data[:colour] || @colour).combined,
                              new_data[:hoist].nil? ? @hoist : new_data[:hoist],
                              new_data[:mentionable].nil? ? @mentionable : new_data[:mentionable],
                              new_data[:permissions] || @permissions.bits)
      update_data(new_data)
    end
  end
end
