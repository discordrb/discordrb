# frozen_string_literal: true

module Discordrb
  # A permissions overwrite, when applied to channels describes additional
  # permissions a member needs to perform certain actions in context.
  class Overwrite
    # Object types an overwrite can apply to.
    TYPES = {
      0 => :role,
      1 => :member
    }.freeze

    # @return [Integer] ID of the thing associated with this overwrite type
    attr_accessor :id

    # @return [Symbol] either :role or :member
    attr_accessor :type

    # @return [Permissions] allowed permissions for this overwrite type
    attr_accessor :allow

    # @return [Permissions] denied permissions for this overwrite type
    attr_accessor :deny

    # Creates a new Overwrite object
    # @example Create an overwrite for a role that can mention everyone, send TTS messages, but can't create instant invites
    #   allow = Discordrb::Permissions.new
    #   allow.can_mention_everyone = true
    #   allow.can_send_tts_messages = true
    #
    #   deny = Discordrb::Permissions.new
    #   deny.can_create_instant_invite = true
    #
    #   # Find some role by name
    #   role = server.roles.find { |r| r.name == 'some role' }
    #
    #   Overwrite.new(role, allow: allow, deny: deny)
    # @example Create an overwrite by ID and permissions bits
    #   Overwrite.new(120571255635181568, type: 'member', allow: 1024, deny: 0)
    # @param object [Integer, #id] the ID or object this overwrite is for
    # @param type [String, Symbol, Integer] the type of object this overwrite is for (only required if object is an Integer)
    # @param allow [Integer, Permissions] allowed permissions for this overwrite, by bits or a Permissions object
    # @param deny [Integer, Permissions] denied permissions for this overwrite, by bits or a Permissions object
    # @raise [ArgumentError] if type is not valid.
    def initialize(object = nil, type: nil, allow: 0, deny: 0)
      @id = object.respond_to?(:id) ? object.id : object

      @type = if object.is_a?(User) || object.is_a?(Member) || object.is_a?(Recipient) || object.is_a?(Profile)
                :member
              elsif object.is_a? Role
                :role
              elsif type.is_a?(String) || type.is_a?(Symbol) && TYPES.value?(type.to_sym)
                type.to_sym
              elsif TYPES[type]
                TYPES[type]
              else
                raise ArgumentError, "Invalid overwrite type: #{type}"
              end

      @allow = allow.is_a?(Permissions) ? allow : Permissions.new(allow)
      @deny = deny.is_a?(Permissions) ? deny : Permissions.new(deny)
    end

    # Comparison by attributes [:id, :type, :allow, :deny]
    def ==(other)
      false unless other.is_a? Discordrb::Overwrite
      id == other.id &&
        type == other.type &&
        allow == other.allow &&
        deny == other.deny
    end

    # @return [Overwrite] create an overwrite from a hash payload
    # @!visibility private
    def self.from_hash(data)
      new(
        data['id'].to_i,
        type: data['type'],
        allow: Permissions.new(data['allow']),
        deny: Permissions.new(data['deny'])
      )
    end

    # @return [Overwrite] copies an overwrite from another Overwrite
    # @!visibility private
    def self.from_other(other)
      new(
        other.id,
        type: other.type,
        allow: Permissions.new(other.allow.bits),
        deny: Permissions.new(other.deny.bits)
      )
    end

    # @return [Hash] hash representation of an overwrite
    # @!visibility private
    def to_hash
      {
        id: id,
        type: type,
        allow: allow.bits,
        deny: deny.bits
      }
    end
  end
end
