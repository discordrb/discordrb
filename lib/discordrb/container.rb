require 'discordrb/events/message'
require 'discordrb/events/typing'
require 'discordrb/events/lifetime'
require 'discordrb/events/presence'
require 'discordrb/events/voice_state_update'
require 'discordrb/events/channel_create'
require 'discordrb/events/channel_update'
require 'discordrb/events/channel_delete'
require 'discordrb/events/members'
require 'discordrb/events/guild_role_create'
require 'discordrb/events/guild_role_delete'
require 'discordrb/events/guild_role_update'
require 'discordrb/events/guilds'
require 'discordrb/events/await'
require 'discordrb/events/bans'

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
    # @option attributes [String] :content Exactly matches the entire content of the message.
    # @option attributes [Time] :after Matches a time after the time the message was sent at.
    # @option attributes [Time] :before Matches a time before the time the message was sent at.
    # @option attributes [Boolean] :private Matches whether or not the channel is private.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [MessageEvent] The event that was raised.
    # @return [MessageEventHandler] The event handler that was registered.
    def message(attributes = {}, &block)
      register_event(MessageEvent, attributes, block)
    end

    # This **event** is raised when the READY packet is received, i. e. servers and channels have finished
    # initialization. It's the recommended way to do things when the bot has finished starting up.
    # @param attributes [Hash] Event attributes, none in this particular case
    # @yield The block is executed when the event is raised.
    # @yieldparam event [ReadyEvent] The event that was raised.
    # @return [ReadyEventHandler] The event handler that was registered.
    def ready(attributes = {}, &block)
      register_event(ReadyEvent, attributes, block)
    end

    # This **event** is raised when the bot has disconnected from the WebSocket, due to the {Bot#stop} method or
    # external causes. It's the recommended way to do clean-up tasks.
    # @param attributes [Hash] Event attributes, none in this particular case
    # @yield The block is executed when the event is raised.
    # @yieldparam event [DisconnectEvent] The event that was raised.
    # @return [DisconnectEventHandler] The event handler that was registered.
    def disconnected(attributes = {}, &block)
      register_event(DisconnectEvent, attributes, block)
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
    # @return [TypingEventHandler] The event handler that was registered.
    def typing(attributes = {}, &block)
      register_event(TypingEvent, attributes, block)
    end

    # This **event** is raised when a message is edited in a channel.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [#resolve_id] :id Matches the ID of the message that was edited.
    # @option attributes [String, Integer, Channel] :in Matches the channel the message was edited in.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [MessageEditEvent] The event that was raised.
    # @return [MessageEditEventHandler] The event handler that was registered.
    def message_edit(attributes = {}, &block)
      register_event(MessageEditEvent, attributes, block)
    end

    # This **event** is raised when a message is deleted in a channel.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [#resolve_id] :id Matches the ID of the message that was deleted.
    # @option attributes [String, Integer, Channel] :in Matches the channel the message was deleted in.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [MessageDeleteEvent] The event that was raised.
    # @return [MessageDeleteEventHandler] The event handler that was registered.
    def message_delete(attributes = {}, &block)
      register_event(MessageDeleteEvent, attributes, block)
    end

    # This **event** is raised when a user's status (online/offline/idle) changes.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String, Integer, User] :from Matches the user whose status changed.
    # @option attributes [:offline, :idle, :online] :status Matches the status the user has now.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [PresenceEvent] The event that was raised.
    # @return [PresenceEventHandler] The event handler that was registered.
    def presence(attributes = {}, &block)
      register_event(PresenceEvent, attributes, block)
    end

    # This **event** is raised when the game a user is playing changes.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String, Integer, User] :from Matches the user whose playing game changes.
    # @option attributes [String] :game Matches the game the user is now playing.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [PlayingEvent] The event that was raised.
    # @return [PlayingEventHandler] The event handler that was registered.
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
    # @option attributes [String] :content Exactly matches the entire content of the message.
    # @option attributes [Time] :after Matches a time after the time the message was sent at.
    # @option attributes [Time] :before Matches a time before the time the message was sent at.
    # @option attributes [Boolean] :private Matches whether or not the channel is private.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [MentionEvent] The event that was raised.
    # @return [MentionEventHandler] The event handler that was registered.
    def mention(attributes = {}, &block)
      register_event(MentionEvent, attributes, block)
    end

    # This **event** is raised when a channel is created.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String] :type Matches the type of channel that is being created (text or voice)
    # @option attributes [String] :name Matches the name of the created channel.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [ChannelCreateEvent] The event that was raised.
    # @return [ChannelCreateEventHandler] The event handler that was registered.
    def channel_create(attributes = {}, &block)
      register_event(ChannelCreateEvent, attributes, block)
    end

    # This **event** is raised when a channel is updated.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String] :type Matches the type of channel that is being updated (text or voice)
    # @option attributes [String] :name Matches the new name of the channel.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [ChannelUpdateEvent] The event that was raised.
    # @return [ChannelUpdateEventHandler] The event handler that was registered.
    def channel_update(attributes = {}, &block)
      register_event(ChannelUpdateEvent, attributes, block)
    end

    # This **event** is raised when a channel is updated.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String] :type Matches the type of channel that is being deleted (text or voice)
    # @option attributes [String] :name Matches the name of the deleted channel.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [ChannelDeleteEvent] The event that was raised.
    # @return [ChannelDeleteEventHandler] The event handler that was registered.
    def channel_delete(attributes = {}, &block)
      register_event(ChannelDeleteEvent, attributes, block)
    end

    # This **event** is raised when a user's voice state changes.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String, Integer, User] :from Matches the user that sent the message.
    # @option attributes [String, Integer, Channel] :channel Matches the voice channel the user has joined.
    # @option attributes [true, false] :mute Matches whether or not the user is muted server-wide.
    # @option attributes [true, false] :deaf Matches whether or not the user is deafened server-wide.
    # @option attributes [true, false] :self_mute Matches whether or not the user is muted by the bot.
    # @option attributes [true, false] :self_deaf Matches whether or not the user is deafened by the bot.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [VoiceStateUpdateEvent] The event that was raised.
    # @return [VoiceStateUpdateEventHandler] The event handler that was registered.
    def voice_state_update(attributes = {}, &block)
      register_event(VoiceStateUpdateEvent, attributes, block)
    end

    # This **event** is raised when a new user joins a server.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String] :username Matches the username of the joined user.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [GuildMemberAddEvent] The event that was raised.
    # @return [GuildMemberAddEventHandler] The event handler that was registered.
    def member_join(attributes = {}, &block)
      register_event(GuildMemberAddEvent, attributes, block)
    end

    # This **event** is raised when a member update happens.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String] :username Matches the username of the updated user.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [GuildMemberUpdateEvent] The event that was raised.
    # @return [GuildMemberUpdateEventHandler] The event handler that was registered.
    def member_update(attributes = {}, &block)
      register_event(GuildMemberUpdateEvent, attributes, block)
    end

    # This **event** is raised when a member leaves a server.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String] :username Matches the username of the member.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [GuildMemberDeleteEvent] The event that was raised.
    # @return [GuildMemberDeleteEventHandler] The event handler that was registered.
    def member_leave(attributes = {}, &block)
      register_event(GuildMemberDeleteEvent, attributes, block)
    end

    # This **event** is raised when a user is banned from a server.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String, Integer, User] :user Matches the user that was banned.
    # @option attributes [String, Integer, Server] :server Matches the server from which the user was banned.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [UserBanEvent] The event that was raised.
    # @return [UserBanEventHandler] The event handler that was registered.
    def user_ban(attributes = {}, &block)
      register_event(UserBanEvent, attributes, block)
    end

    # This **event** is raised when a user is unbanned from a server.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String, Integer, User] :user Matches the user that was unbanned.
    # @option attributes [String, Integer, Server] :server Matches the server from which the user was unbanned.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [UserUnbanEvent] The event that was raised.
    # @return [UserUnbanEventHandler] The event handler that was registered.
    def user_unban(attributes = {}, &block)
      register_event(UserUnbanEvent, attributes, block)
    end

    # This **event** is raised when a server is created respective to the bot, i. e. the bot joins a server or creates
    # a new one itself. It should never be necessary to listen to this event as it will only ever be triggered by
    # things the bot itself does, but one can never know.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String, Integer, Server] :server Matches the server that was created.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [GuildCreateEvent] The event that was raised.
    # @return [GuildCreateEventHandler] The event handler that was registered.
    def server_create(attributes = {}, &block)
      register_event(GuildCreateEvent, attributes, block)
    end

    # This **event** is raised when a server is updated, for example if the name or region has changed.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String, Integer, Server] :server Matches the server that was updated.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [GuildUpdateEvent] The event that was raised.
    # @return [GuildUpdateEventHandler] The event handler that was registered.
    def server_update(attributes = {}, &block)
      register_event(GuildUpdateEvent, attributes, block)
    end

    # This **event** is raised when a server is deleted, or when the bot leaves a server. (These two cases are identical
    # to Discord.)
    # @param attributes [Hash] The event's attributes.
    # @option attributes [String, Integer, Server] :server Matches the server that was deleted.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [GuildDeleteEvent] The event that was raised.
    # @return [GuildDeleteEventHandler] The event handler that was registered.
    def server_delete(attributes = {}, &block)
      register_event(GuildDeleteEvent, attributes, block)
    end

    # This **event** is raised when an {Await} is triggered. It provides an easy way to execute code
    # on an await without having to rely on the await's block.
    # @param attributes [Hash] The event's attributes.
    # @option attributes [Symbol] :key Exactly matches the await's key.
    # @option attributes [Class] :type Exactly matches the event's type.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [AwaitEvent] The event that was raised.
    # @return [AwaitEventHandler] The event handler that was registered.
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
    # @option attributes [String] :content Exactly matches the entire content of the message.
    # @option attributes [Time] :after Matches a time after the time the message was sent at.
    # @option attributes [Time] :before Matches a time before the time the message was sent at.
    # @option attributes [Boolean] :private Matches whether or not the channel is private.
    # @yield The block is executed when the event is raised.
    # @yieldparam event [PrivateMessageEvent] The event that was raised.
    # @return [PrivateMessageEventHandler] The event handler that was registered.
    def pm(attributes = {}, &block)
      register_event(PrivateMessageEvent, attributes, block)
    end

    alias_method :private_message, :pm

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
      fail "Couldn't include the container #{container} as it doesn't have any event handlers - have you tried to include a commands container into an event-only bot?" unless handlers
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
