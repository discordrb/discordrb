# frozen_string_literal: true

require 'discordrb/events/message'
require 'discordrb/events/typing'
require 'discordrb/events/lifetime'
require 'discordrb/events/presence'
require 'discordrb/events/voice_state_update'
require 'discordrb/events/channels'
require 'discordrb/events/members'
require 'discordrb/events/roles'
require 'discordrb/events/guilds'
require 'discordrb/events/await'
require 'discordrb/events/bans'
require 'discordrb/events/reactions'

require 'discordrb/await'

module Discordrb
  # This module provides the functionality required for events and awaits. It is separated
  # from the {Bot} class so users can make their own container modules and include them.
  module EventContainer
    # This **event** is raised when a message is sent to a text channel the bot is currently in.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String, Regexp] :start_with Matches the string the message starts with.
    # @option attributes [String, Regexp] :end_with Matches the string the message ends with.
    # @option attributes [String, Regexp] :contains Matches a string the message contains.
    # @option attributes [String, Integer, Channel] :in Matches the channel the message was sent in.
    # @option attributes [String, Integer, User] :from Matches the user that sent the message.
    # @option attributes [String] :content Exactly matches the entire content of the message.
    # @option attributes [Time] :after Matches a time after the time the message was sent at.
    # @option attributes [Time] :before Matches a time before the time the message was sent at.
    # @option attributes [Boolean] :private Matches whether or not the channel is private.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [MessageEvent] The event that was raised.
    # @return [MessageEventHandler] the event handler that was registered.
    def message(attributes = {}, &block)
      register_event(MessageEvent, attributes, block)
    end

    # This **event** is raised when the READY packet is received, i. e. servers and channels have finished
    # initialization. It's the recommended way to do things when the bot has finished starting up.
    # @param attributes [Hash] Event attributes, none in this particular case
    # @yield The block is executed when the event is raised.
    # @yieldparam event [ReadyEvent] The event that was raised.
    # @return [ReadyEventHandler] the event handler that was registered.
    def ready(attributes = {}, &block)
      register_event(ReadyEvent, attributes, block)
    end

    # This **event** is raised when the bot has disconnected from the WebSocket, due to the {Bot#stop} method or
    # external causes. It's the recommended way to do clean-up tasks.
    # @param attributes [Hash] Event attributes, none in this particular case
    # @yield The block is executed when the event is raised.
    # @yieldparam event [DisconnectEvent] The event that was raised.
    # @return [DisconnectEventHandler] the event handler that was registered.
    def disconnected(attributes = {}, &block)
      register_event(DisconnectEvent, attributes, block)
    end

    # This **event** is raised every time the bot sends a heartbeat over the galaxy. This happens roughly every 40
    # seconds, but may happen at a lower rate should Discord change their interval. It may also happen more quickly for
    # periods of time, especially for unstable connections, since discordrb rather sends a heartbeat than not if there's
    # a choice. (You shouldn't rely on all this to be accurately timed.)
    #
    # All this makes this event useful to periodically trigger something, like doing some API request every hour,
    # setting some kind of uptime variable or whatever else. The only limit is yourself.
    # @param attributes [Hash] Event attributes, none in this particular case
    # @yield The block is executed when the event is raised.
    # @yieldparam event [HeartbeatEvent] The event that was raised.
    # @return [HeartbeatEventHandler] the event handler that was registered.
    def heartbeat(attributes = {}, &block)
      register_event(HeartbeatEvent, attributes, block)
    end

    # This **event** is raised when somebody starts typing in a channel the bot is also in. The official Discord
    # client would display the typing indicator for five seconds after receiving this event. If the user continues
    # typing after five seconds, the event will be re-raised.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String, Integer, Channel] :in Matches the channel where typing was started.
    # @option attributes [String, Integer, User] :from Matches the user that started typing.
    # @option attributes [Time] :after Matches a time after the time the typing started.
    # @option attributes [Time] :before Matches a time before the time the typing started.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [TypingEvent] The event that was raised.
    # @return [TypingEventHandler] the event handler that was registered.
    def typing(attributes = {}, &block)
      register_event(TypingEvent, attributes, block)
    end

    # This **event** is raised when a message is edited in a channel.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [#resolve_id] :id Matches the ID of the message that was edited.
    # @option attributes [String, Integer, Channel] :in Matches the channel the message was edited in.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [MessageEditEvent] The event that was raised.
    # @return [MessageEditEventHandler] the event handler that was registered.
    def message_edit(attributes = {}, &block)
      register_event(MessageEditEvent, attributes, block)
    end

    # This **event** is raised when a message is deleted in a channel.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [#resolve_id] :id Matches the ID of the message that was deleted.
    # @option attributes [String, Integer, Channel] :in Matches the channel the message was deleted in.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [MessageDeleteEvent] The event that was raised.
    # @return [MessageDeleteEventHandler] the event handler that was registered.
    def message_delete(attributes = {}, &block)
      register_event(MessageDeleteEvent, attributes, block)
    end

    # This **event** is raised when somebody reacts to a message.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [Integer, String] :emoji Matches the ID of the emoji that was reacted with, or its name.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [ReactionAddEvent] The event that was raised.
    # @return [ReactionAddEventHandler] The event handler that was registered.
    def reaction_add(attributes = {}, &block)
      register_event(ReactionAddEvent, attributes, block)
    end

    # This **event** is raised when somebody removes a reaction from a message.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [Integer, String] :emoji Matches the ID of the emoji that was removed from the reactions, or
    #   its name.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [ReactionRemoveEvent] The event that was raised.
    # @return [ReactionRemoveEventHandler] The event handler that was registered.
    def reaction_remove(attributes = {}, &block)
      register_event(ReactionRemoveEvent, attributes, block)
    end

    # This **event** is raised when somebody removes all reactions from a message.
    # @param attributes [Hash] The event's attributes.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [ReactionRemoveAllEvent] The event that was raised.
    # @return [ReactionRemoveAllEventHandler] The event handler that was registered.
    def reaction_remove_all(attributes = {}, &block)
      register_event(ReactionRemoveAllEvent, attributes, block)
    end

    # This **event** is raised when a user's status (online/offline/idle) changes.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String, Integer, User] :from Matches the user whose status changed.
    # @option attributes [:offline, :idle, :online] :status Matches the status the user has now.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [PresenceEvent] The event that was raised.
    # @return [PresenceEventHandler] the event handler that was registered.
    def presence(attributes = {}, &block)
      register_event(PresenceEvent, attributes, block)
    end

    # This **event** is raised when the game a user is playing changes.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String, Integer, User] :from Matches the user whose playing game changes.
    # @option attributes [String] :game Matches the game the user is now playing.
    # @option attributes [Integer] :type Matches the type of game object (0 game, 1 Twitch stream)
    # @yield The block is executed when the event is raised.
    # @yieldparam event [PlayingEvent] The event that was raised.
    # @return [PlayingEventHandler] the event handler that was registered.
    def playing(attributes = {}, &block)
      register_event(PlayingEvent, attributes, block)
    end

    # This **event** is raised when the bot is mentioned in a message.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String, Regexp] :start_with Matches the string the message starts with.
    # @option attributes [String, Regexp] :end_with Matches the string the message ends with.
    # @option attributes [String, Regexp] :contains Matches a string the message contains.
    # @option attributes [String, Integer, Channel] :in Matches the channel the message was sent in.
    # @option attributes [String, Integer, User] :from Matches the user that sent the message.
    # @option attributes [String] :content Exactly matches the entire content of the message.
    # @option attributes [Time] :after Matches a time after the time the message was sent at.
    # @option attributes [Time] :before Matches a time before the time the message was sent at.
    # @option attributes [Boolean] :private Matches whether or not the channel is private.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [MentionEvent] The event that was raised.
    # @return [MentionEventHandler] the event handler that was registered.
    def mention(attributes = {}, &block)
      register_event(MentionEvent, attributes, block)
    end

    # This **event** is raised when a channel is created.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [Integer] :type Matches the type of channel that is being created (0: text, 1: private, 2: voice, 3: group)
    # @option attributes [String] :name Matches the name of the created channel.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [ChannelCreateEvent] The event that was raised.
    # @return [ChannelCreateEventHandler] the event handler that was registered.
    def channel_create(attributes = {}, &block)
      register_event(ChannelCreateEvent, attributes, block)
    end

    # This **event** is raised when a channel is updated.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [Integer] :type Matches the type of channel that is being updated (0: text, 1: private, 2: voice, 3: group).
    # @option attributes [String] :name Matches the new name of the channel.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [ChannelUpdateEvent] The event that was raised.
    # @return [ChannelUpdateEventHandler] the event handler that was registered.
    def channel_update(attributes = {}, &block)
      register_event(ChannelUpdateEvent, attributes, block)
    end

    # This **event** is raised when a channel is deleted.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [Integer] :type Matches the type of channel that is being deleted (0: text, 1: private, 2: voice, 3: group).
    # @option attributes [String] :name Matches the name of the deleted channel.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [ChannelDeleteEvent] The event that was raised.
    # @return [ChannelDeleteEventHandler] the event handler that was registered.
    def channel_delete(attributes = {}, &block)
      register_event(ChannelDeleteEvent, attributes, block)
    end

    # This **event** is raised when a recipient is added to a group channel.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String] :name Matches the name of the group channel that the recipient is added to.
    # @option attributes [#resolve_id] :owner_id Matches the id of the group channel's owner.
    # @option attributes [#resolve_id] :id Matches the id of the recipient added to the group channel.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [ChannelRecipientAddEvent] The event that was raised.
    # @return [ChannelRecipientAddHandler] the event handler that was registered.
    def channel_recipient_add(attributes = {}, &block)
      register_event(ChannelRecipientAddEvent, attributes, block)
    end

    # This **event** is raised when a recipient is removed from a group channel.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String] :name Matches the name of the group channel that the recipient is added to.
    # @option attributes [#resolve_id] :owner_id Matches the id of the group channel's owner.
    # @option attributes [#resolve_id] :id Matches the id of the recipient removed from the group channel.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [ChannelRecipientRemoveEvent] The event that was raised.
    # @return [ChannelRecipientRemoveHandler] the event handler that was registered.
    def channel_recipient_remove(attributes = {}, &block)
      register_event(ChannelRecipientRemoveEvent, attributes, block)
    end

    # This **event** is raised when a user's voice state changes.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String, Integer, User] :from Matches the user that sent the message.
    # @option attributes [String, Integer, Channel] :channel Matches the voice channel the user has joined.
    # @option attributes [String, Integer, Channel] :old_channel Matches the voice channel the user was in previously.
    # @option attributes [true, false] :mute Matches whether or not the user is muted server-wide.
    # @option attributes [true, false] :deaf Matches whether or not the user is deafened server-wide.
    # @option attributes [true, false] :self_mute Matches whether or not the user is muted by the bot.
    # @option attributes [true, false] :self_deaf Matches whether or not the user is deafened by the bot.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [VoiceStateUpdateEvent] The event that was raised.
    # @return [VoiceStateUpdateEventHandler] the event handler that was registered.
    def voice_state_update(attributes = {}, &block)
      register_event(VoiceStateUpdateEvent, attributes, block)
    end

    # This **event** is raised when a new user joins a server.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String] :username Matches the username of the joined user.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [ServerMemberAddEvent] The event that was raised.
    # @return [ServerMemberAddEventHandler] the event handler that was registered.
    def member_join(attributes = {}, &block)
      register_event(ServerMemberAddEvent, attributes, block)
    end

    # This **event** is raised when a member update happens.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String] :username Matches the username of the updated user.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [ServerMemberUpdateEvent] The event that was raised.
    # @return [ServerMemberUpdateEventHandler] the event handler that was registered.
    def member_update(attributes = {}, &block)
      register_event(ServerMemberUpdateEvent, attributes, block)
    end

    # This **event** is raised when a member leaves a server.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String] :username Matches the username of the member.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [ServerMemberDeleteEvent] The event that was raised.
    # @return [ServerMemberDeleteEventHandler] the event handler that was registered.
    def member_leave(attributes = {}, &block)
      register_event(ServerMemberDeleteEvent, attributes, block)
    end

    # This **event** is raised when a user is banned from a server.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String, Integer, User] :user Matches the user that was banned.
    # @option attributes [String, Integer, Server] :server Matches the server from which the user was banned.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [UserBanEvent] The event that was raised.
    # @return [UserBanEventHandler] the event handler that was registered.
    def user_ban(attributes = {}, &block)
      register_event(UserBanEvent, attributes, block)
    end

    # This **event** is raised when a user is unbanned from a server.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String, Integer, User] :user Matches the user that was unbanned.
    # @option attributes [String, Integer, Server] :server Matches the server from which the user was unbanned.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [UserUnbanEvent] The event that was raised.
    # @return [UserUnbanEventHandler] the event handler that was registered.
    def user_unban(attributes = {}, &block)
      register_event(UserUnbanEvent, attributes, block)
    end

    # This **event** is raised when a server is created respective to the bot, i. e. the bot joins a server or creates
    # a new one itself. It should never be necessary to listen to this event as it will only ever be triggered by
    # things the bot itself does, but one can never know.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String, Integer, Server] :server Matches the server that was created.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [ServerCreateEvent] The event that was raised.
    # @return [ServerCreateEventHandler] the event handler that was registered.
    def server_create(attributes = {}, &block)
      register_event(ServerCreateEvent, attributes, block)
    end

    # This **event** is raised when a server is updated, for example if the name or region has changed.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String, Integer, Server] :server Matches the server that was updated.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [ServerUpdateEvent] The event that was raised.
    # @return [ServerUpdateEventHandler] the event handler that was registered.
    def server_update(attributes = {}, &block)
      register_event(ServerUpdateEvent, attributes, block)
    end

    # This **event** is raised when a server is deleted, or when the bot leaves a server. (These two cases are identical
    # to Discord.)
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String, Integer, Server] :server Matches the server that was deleted.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [ServerDeleteEvent] The event that was raised.
    # @return [ServerDeleteEventHandler] the event handler that was registered.
    def server_delete(attributes = {}, &block)
      register_event(ServerDeleteEvent, attributes, block)
    end

    # This **event** is raised when an emoji or collection of emojis is created/deleted/updated.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String, Integer, Server] :server Matches the server.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [ServerEmojiChangeEvent] The event that was raised.
    # @return [ServerEmojiChangeEventHandler] the event handler that was registered.
    def server_emoji(attributes = {}, &block)
      register_event(ServerEmojiChangeEvent, attributes, block)
    end

    # This **event** is raised when an emoji is created.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String, Integer, Server] :server Matches the server.
    # @option attributes [String, Integer] :id Matches the id of the emoji.
    # @option attributes [String] :name Matches the name of the emoji.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [ServerEmojiCreateEvent] The event that was raised.
    # @return [ServerEmojiCreateEventHandler] the event handler that was registered.
    def server_emoji_create(attributes = {}, &block)
      register_event(ServerEmojiCreateEvent, attributes, block)
    end

    # This **event** is raised when an emoji is deleted.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String, Integer, Server] :server Matches the server.
    # @option attributes [String, Integer] :id Matches the id of the emoji.
    # @option attributes [String] :name Matches the name of the emoji.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [ServerEmojiDeleteEvent] The event that was raised.
    # @return [ServerEmojiDeleteEventHandler] the event handler that was registered.
    def server_emoji_delete(attributes = {}, &block)
      register_event(ServerEmojiDeleteEvent, attributes, block)
    end

    # This **event** is raised when an emoji is updated.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String, Integer, Server] :server Matches the server.
    # @option attributes [String, Integer] :id Matches the id of the emoji.
    # @option attributes [String] :name Matches the name of the emoji.
    # @option attributes [String] :old_name Matches the name of the emoji before the update.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [ServerEmojiUpdateEvent] The event that was raised.
    # @return [ServerEmojiUpdateEventHandler] the event handler that was registered.
    def server_emoji_update(attributes = {}, &block)
      register_event(ServerEmojiUpdateEvent, attributes, block)
    end

    # This **event** is raised when an {Await} is triggered. It provides an easy way to execute code
    # on an await without having to rely on the await's block.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [Symbol] :key Exactly matches the await's key.
    # @option attributes [Class] :type Exactly matches the event's type.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [AwaitEvent] The event that was raised.
    # @return [AwaitEventHandler] the event handler that was registered.
    def await(attributes = {}, &block)
      register_event(AwaitEvent, attributes, block)
    end

    # This **event** is raised when a private message is sent to the bot.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String, Regexp] :start_with Matches the string the message starts with.
    # @option attributes [String, Regexp] :end_with Matches the string the message ends with.
    # @option attributes [String, Regexp] :contains Matches a string the message contains.
    # @option attributes [String, Integer, Channel] :in Matches the channel the message was sent in.
    # @option attributes [String, Integer, User] :from Matches the user that sent the message.
    # @option attributes [String] :content Exactly matches the entire content of the message.
    # @option attributes [Time] :after Matches a time after the time the message was sent at.
    # @option attributes [Time] :before Matches a time before the time the message was sent at.
    # @option attributes [Boolean] :private Matches whether or not the channel is private.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [PrivateMessageEvent] The event that was raised.
    # @return [PrivateMessageEventHandler] the event handler that was registered.
    def pm(attributes = {}, &block)
      register_event(PrivateMessageEvent, attributes, block)
    end

    alias_method :private_message, :pm
    alias_method :direct_message, :pm
    alias_method :dm, :pm

    # This **event** is raised for every dispatch received over the gateway, whether supported by discordrb or not.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String, Symbol, Regexp] :type Matches the event type of the dispatch.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [RawEvent] The event that was raised.
    # @return [RawEventHandler] The event handler that was registered.
    def raw(attributes = {}, &block)
      register_event(RawEvent, attributes, block)
    end

    # This **event** is raised for a dispatch received over the gateway that is not currently handled otherwise by
    # discordrb.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String, Symbol, Regexp] :type Matches the event type of the dispatch.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [UnknownEvent] The event that was raised.
    # @return [UnknownEventHandler] The event handler that was registered.
    def unknown(attributes = {}, &block)
      register_event(UnknownEvent, attributes, block)
    end

    # Removes an event handler from this container. If you're looking for a way to do temporary events, I recommend
    # {Await}s instead of this.
    # @param handler [Discordrb::Events::EventHandler] The handler to remove.
    def remove_handler(handler)
      clazz = EventContainer.event_class(handler.class)
      @event_handlers ||= {}
      @event_handlers[clazz].delete(handler)
    end

    # Removes all events from this event handler.
    def clear!
      @event_handlers.clear if @event_handlers
    end

    # Adds an event handler to this container. Usually, it's more expressive to just use one of the shorthand adder
    # methods like {#message}, but if you want to create one manually you can use this.
    # @param handler [Discordrb::Events::EventHandler] The handler to add.
    def add_handler(handler)
      clazz = EventContainer.event_class(handler.class)
      @event_handlers ||= {}
      @event_handlers[clazz] << handler
    end

    # Adds all event handlers from another container into this one. Existing event handlers will be overwritten.
    # @param container [Module] A module that `extend`s {EventContainer} from which the handlers will be added.
    def include_events(container)
      handlers = container.instance_variable_get '@event_handlers'
      return unless handlers

      @event_handlers ||= {}
      @event_handlers.merge!(handlers) { |_, old, new| old + new }
    end

    alias_method :include!, :include_events
    alias_method :<<, :add_handler

    # Returns the handler class for an event class type
    # @see #event_class
    # @param event_class [Class] The event type
    # @return [Class] the handler type
    def self.handler_class(event_class)
      class_from_string(event_class.to_s + 'Handler')
    end

    # Returns the event class for a handler class type
    # @see #handler_class
    # @param handler_class [Class] The handler type
    # @return [Class, nil] the event type, or nil if the handler_class isn't a handler class (i. e. ends with Handler)
    def self.event_class(handler_class)
      class_name = handler_class.to_s
      return nil unless class_name.end_with? 'Handler'

      EventContainer.class_from_string(class_name[0..-8])
    end

    # Utility method to return a class object from a string of its name. Mostly useful for internal stuff
    # @param str [String] The name of the class
    # @return [Class] the class
    def self.class_from_string(str)
      str.split('::').inject(Object) do |mod, class_name|
        mod.const_get(class_name)
      end
    end

    private

    include Discordrb::Events

    def register_event(clazz, attributes, block)
      handler = EventContainer.handler_class(clazz).new(attributes, block)

      @event_handlers ||= {}
      @event_handlers[clazz] ||= []
      @event_handlers[clazz] << handler

      # Return the handler so it can be removed later
      handler
    end
  end
end
