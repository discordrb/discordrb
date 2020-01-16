# frozen_string_literal: true

require 'discordrb/version'
require 'discordrb/bot'
require 'discordrb/commands/command_bot'
require 'discordrb/logger'

# All discordrb functionality, to be extended by other files
module Discordrb
  Thread.current[:discordrb_name] = 'main'

  # The default debug logger used by discordrb.
  LOGGER = Logger.new(ENV['DISCORDRB_FANCY_LOG'])

  # The unix timestamp Discord IDs are based on
  DISCORD_EPOCH = 1_420_070_400_000

  INTENTS = {
    guilds: 1 << 0,
    guild_create: 1 << 0,
    guild_delete: 1 << 0,
    guild_role_create: 1 << 0,
    guild_role_update: 1 << 0,
    guild_role_delete: 1 << 0,
    channel_create: 1  << 0,
    channel_update: 1  << 0,
    channel_delete: 1 << 0,
    channel_pins_update: 1 << 0,

    guild_members: 1 << 1,
    guild_member_add: 1 << 1,
    guild_member_update: 1 << 1,
    guild_member_remove: 1 << 1,

    guild_bans: 1 << 2,
    guild_ban_add: 1 << 2,
    guild_ban_remove: 1 << 2,

    guild_emojis: 1 << 3,
    guild_emojis_update: 1 << 3,

    guild_integrations: 1 << 4,
    guild_integrations_update: 1 << 4,

    guild_webhooks: 1 << 5,
    webhooks_update: 1 << 5,

    guild_invites: 1 << 6,
    invite_create: 1 << 6,
    invite_delete: 1 << 6,

    guild_voice_states: 1 << 7,
    voice_state_update: 1 << 7,

    guild_presences: 1 << 8,
    presence_update: 1 << 8,

    guild_messages: 1 << 9,
    message_create: 1 << 9,
    message_update: 1 << 9,
    message_delete: 1 << 9,

    guild_message_reactions: 1 << 10,
    message_reaction_add: 1 << 10,
    message_reaction_remove: 1 << 10,
    message_reaction_remove_all: 1 << 10,
    message_reaction_remove_emoji: 1 << 10,

    guild_message_typing: 1 << 11,
    typing_start: 1 << 11,

    direct_messages: 1 << 12,
    direct_message_channel_create: 1 << 12,
    direct_message_create: 1 << 12,
    direct_message_update: 1 << 12,
    direct_message_delete: 1 << 12,

    direct_message_reactions: 1 << 13,
    direct_message_reaction_add: 1 << 13,
    direct_message_reaction_remove: 1 << 13,
    direct_message_reaction_remove_all: 1 << 13,
    direct_message_reaction_remove_emoji: 1 << 13,

    direct_message_typing: 1 << 14,

    none: 0,
    all: (0..14).reduce { |x, y| x | (1 << y) }
  }.freeze

  # Compares two objects based on IDs - either the objects' IDs are equal, or one object is equal to the other's ID.
  def self.id_compare(one_id, other)
    other.respond_to?(:resolve_id) ? (one_id.resolve_id == other.resolve_id) : (one_id == other)
  end

  # The maximum length a Discord message can have
  CHARACTER_LIMIT = 2000

  # Splits a message into chunks of 2000 characters. Attempts to split by lines if possible.
  # @param msg [String] The message to split.
  # @return [Array<String>] the message split into chunks
  def self.split_message(msg)
    # If the messages is empty, return an empty array
    return [] if msg.empty?

    # Split the message into lines
    lines = msg.lines

    # Turn the message into a "triangle" of consecutively longer slices, for example the array [1,2,3,4] would become
    # [
    #  [1],
    #  [1, 2],
    #  [1, 2, 3],
    #  [1, 2, 3, 4]
    # ]
    tri = (0...lines.length).map { |i| lines.combination(i + 1).first }

    # Join the individual elements together to get an array of strings with consecutively more lines
    joined = tri.map(&:join)

    # Find the largest element that is still below the character limit, or if none such element exists return the first
    ideal = joined.max_by { |e| e.length > CHARACTER_LIMIT ? -1 : e.length }

    # If it's still larger than the character limit (none was smaller than it) split it into the largest chunk without
    # cutting words apart, breaking on the nearest space within character limit, otherwise just return an array with one element
    ideal_ary = ideal.length > CHARACTER_LIMIT ? ideal.split(/(.{1,#{CHARACTER_LIMIT}}\b|.{1,#{CHARACTER_LIMIT}})/).reject(&:empty?) : [ideal]

    # Slice off the ideal part and strip newlines
    rest = msg[ideal.length..-1].strip

    # If none remains, return an empty array -> we're done
    return [] unless rest

    # Otherwise, call the method recursively to split the rest of the string and add it onto the ideal array
    ideal_ary + split_message(rest)
  end
end

# In discordrb, Integer and {String} are monkey-patched to allow for easy resolution of IDs
class Integer
  # @return [Integer] The Discord ID represented by this integer, i.e. the integer itself
  def resolve_id
    self
  end
end

# In discordrb, {Integer} and String are monkey-patched to allow for easy resolution of IDs
class String
  # @return [Integer] The Discord ID represented by this string, i.e. the string converted to an integer
  def resolve_id
    to_i
  end
end
