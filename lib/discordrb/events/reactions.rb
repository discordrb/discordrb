# frozen_string_literal: true

require 'discordrb/events/generic'
require 'discordrb/data'

module Discordrb::Events
  # Generic superclass for events about adding and removing reactions
  class ReactionEvent
    include Respondable

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
  class ReactionEventHandler < EventHandler
    def matches?(event)
      # Check for the proper event type
      return false unless event.is_a? ReactionEvent

      [
        matches_all(@attributes[:emoji], event.emoji) do |a, e|
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

  # Event raised when somebody reacts to a message
  class ReactionAddEvent < ReactionEvent; end

  # Event handler for {ReactionAddEvent}
  class ReactionAddEventHandler < ReactionEventHandler; end

  # Event raised when somebody removes a reaction to a message
  class ReactionRemoveEvent < ReactionEvent; end

  # Event handler for {ReactionRemoveEvent}
  class ReactionRemoveEventHandler < ReactionEventHandler; end

  # Event raised when somebody removes all reactions from a message
  class ReactionRemoveAllEvent
    include Respondable

    def initialize(data, bot)
      @bot = bot

      @message_id = data['message_id'].to_i
      @channel_id = data['channel_id'].to_i
    end

    # @return [Channel] the channel where the removal occurred.
    def channel
      @channel ||= @bot.channel(@channel_id)
    end

    # @return [Message] the message all reactions were removed from.
    def message
      @message ||= channel.load_message(@message_id)
    end
  end

  # Event handler for {ReactionRemoveAllEvent}
  class ReactionRemoveAllEventHandler < EventHandler
    def matches?(event)
      # Check for the proper event type
      return false unless event.is_a? ReactionRemoveAllEvent

      # No attributes yet as there is no property available on the event that doesn't involve doing a resolution request
      [].reduce(true, &:&)
    end
  end
end
