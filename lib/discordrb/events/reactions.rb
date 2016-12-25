# frozen_string_literal: true

require 'discordrb/events/generic'
require 'discordrb/data'

module Discordrb::Events
  # Generic superclass for events about adding and removing reactions
  class ReactionEvent
    # @return [Emoji] the emoji that was reacted with.
    attr_reader :emoji

    def initialize(data, bot)
      @bot = bot

      @emoji = Discordrb::Emoji.new(data['emoji'], bot, nil)
      @user_id = data['user_id'].to_i
      @message_id = data['message_id'].to_i
      @channel_id = data['channel_id'].to_i
    end

    # @return [User] the user that reacted to this message.
    def user
      # Cache the user so we don't do requests all the time
      @user ||= @bot.user(@user_id)
    end

    # @return [Message] the message that was reacted to.
    def message
      @message ||= channel.load_message(@message_id)
    end

    # @return [Channel] the channel that was reacted in.
    def channel
      @channel ||= @bot.channel(@channel_id)
    end
  end

  # Generic superclass for event handlers pertaining to adding and removing reactions
  class ReactionEventHandler
    def matches?(event)
      # Check for the proper event type
      return false unless event.is_a? ReactionEvent

      [
        matches_all(@attributes[:emoji], event.type) do |a, e|
          if a.is_a? Integer
            e.id == a
          elsif a.is_a? String
            e.name == a || e.name == a.delete(':') || e.id == a.resolve_id
          else
            e == a
          end
        end
      ].reduce(true, &:&)
    end
  end
end
