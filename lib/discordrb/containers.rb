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
    # The list of currently running threads used to parse and call events.
    # The threads will have a local variable `:discordrb_name` in the format of `et-1234`, where
    # "et" stands for "event thread" and the number is a continually incrementing number representing
    # how many events were executed before.
    # @return [Array<Thread>] The threads.
    attr_reader :event_threads

    def initialize
      @event_threads = []
      @current_thread = 0
    end

    # Add an await the bot should listen to. For information on awaits, see {Await}.
    # @param key [Symbol] The key that uniquely identifies the await for {AwaitEvent}s to listen to (see {#await}).
    # @param type [Class] The event class that should be listened for.
    # @param attributes [Hash] The attributes the event should check for. The block will only be executed if all attributes match.
    # @yield Is executed when the await is triggered.
    # @yieldparam event [Event] The event object that was triggered.
    # @return [Await] The await that was created.
    def add_await(key, type, attributes = {}, &block)
      fail "You can't await an AwaitEvent!" if type == Discordrb::Events::AwaitEvent
      await = Await.new(self, key, type, attributes, block)
      @awaits ||= {}
      @awaits[key] = await
    end

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

    def ready(attributes = {}, &block)
      register_event(ReadyEvent, attributes, block)
    end

    def disconnected(attributes = {}, &block)
      register_event(DisconnectEvent, attributes, block)
    end

    def typing(attributes = {}, &block)
      register_event(TypingEvent, attributes, block)
    end

    def message_edit(attributes = {}, &block)
      register_event(MessageEditEvent, attributes, block)
    end

    def message_delete(attributes = {}, &block)
      register_event(MessageDeleteEvent, attributes, block)
    end

    def presence(attributes = {}, &block)
      register_event(PresenceEvent, attributes, block)
    end

    def playing(attributes = {}, &block)
      register_event(PlayingEvent, attributes, block)
    end

    def mention(attributes = {}, &block)
      register_event(MentionEvent, attributes, block)
    end

    # Handle channel creation
    # Attributes:
    # * type: Channel type ('text' or 'voice')
    # * name: Channel name
    def channel_create(attributes = {}, &block)
      register_event(ChannelCreateEvent, attributes, block)
    end

    # Handle channel update
    # Attributes:
    # * type: Channel type ('text' or 'voice')
    # * name: Channel name
    def channel_update(attributes = {}, &block)
      register_event(ChannelUpdateEvent, attributes, block)
    end

    # Handle channel deletion
    # Attributes:
    # * type: Channel type ('text' or 'voice')
    # * name: Channel name
    def channel_delete(attributes = {}, &block)
      register_event(ChannelDeleteEvent, attributes, block)
    end

    # Handle a change to a voice state.
    # This includes joining a voice channel or changing mute or deaf state.
    # Attributes:
    # * from: User whose voice state changed
    # * mute: server mute status
    # * deaf: server deaf status
    # * self_mute: self mute status
    # * self_deaf: self deaf status
    # * channel: channel the user joined
    def voice_state_update(attributes = {}, &block)
      register_event(VoiceStateUpdateEvent, attributes, block)
    end

    def member_join(attributes = {}, &block)
      register_event(GuildMemberAddEvent, attributes, block)
    end

    def member_update(attributes = {}, &block)
      register_event(GuildMemberUpdateEvent, attributes, block)
    end

    def member_leave(attributes = {}, &block)
      register_event(GuildMemberDeleteEvent, attributes, block)
    end

    def user_ban(attributes = {}, &block)
      register_event(UserBanEvent, attributes, block)
    end

    def user_unban(attributes = {}, &block)
      register_event(UserUnbanEvent, attributes, block)
    end

    def server_create(attributes = {}, &block)
      register_event(GuildCreateEvent, attributes, block)
    end

    def server_update(attributes = {}, &block)
      register_event(GuildUpdateEvent, attributes, block)
    end

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

    def pm(attributes = {}, &block)
      register_event(PrivateMessageEvent, attributes, block)
    end

    def remove_handler(handler)
      clazz = event_class(handler.class)
      @event_handlers ||= {}
      @event_handlers[clazz].delete(handler)
    end

    def add_handler(handler)
      clazz = event_class(handler.class)
      @event_handlers ||= {}
      @event_handlers[clazz] << handler
    end

    private

    include Discordrb::Events

    def handler_class(event_class)
      class_from_string(event_class.to_s + 'Handler')
    end

    def raise_event(event)
      debug("Raised a #{event.class}")
      handle_awaits(event)

      @event_handlers ||= {}
      handlers = @event_handlers[event.class]
      (handlers || []).each do |handler|
        call_event(handler, event) if handler.matches?(event)
      end
    end

    def call_event(handler, event)
      t = Thread.new do
        @event_threads ||= []
        @current_thread ||= 0

        @event_threads << t
        Thread.current[:discordrb_name] = "et-#{@current_thread += 1}"
        begin
          handler.call(event)
          handler.after_call(event)
        rescue => e
          log_exception(e)
        ensure
          @event_threads.delete(t)
        end
      end
    end

    def handle_awaits(event)
      @awaits ||= {}
      @awaits.each do |_, await|
        key, should_delete = await.match(event)
        next unless key
        debug("should_delete: #{should_delete}")
        @awaits.delete(await.key) if should_delete

        await_event = Discordrb::Events::AwaitEvent.new(await, event, self)
        raise_event(await_event)
      end
    end

    def register_event(clazz, attributes, block)
      handler = handler_class(clazz).new(attributes, block)

      @event_handlers ||= {}
      @event_handlers[clazz] ||= []
      @event_handlers[clazz] << handler

      # Return the handler so it can be removed later
      handler
    end

    def class_from_string(str)
      str.split('::').inject(Object) do |mod, class_name|
        mod.const_get(class_name)
      end
    end

    def event_class(handler_class)
      class_name = handler_class.to_s
      return nil unless class_name.end_with? 'Handler'

      class_from_string(class_name[0..-8])
    end
  end
end
