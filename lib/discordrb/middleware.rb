# frozen_string_literal: true

# {Middleware} is a mixin for {Bot} that allows for event handlers
# that accept chains of custom objects, or *middleware*, that get run *before*
# your handler.
#
# A *middleware* can be *any* `class` that responds to `def call(event, state)`
# and optionally `yield`s. Whether or not your `call` `yield`s or not determines
# if the rest of the chain is executed.a
#
# In `call`, `event` will be the invoking Discord event, and `state` is an
# empty hash that you can store anything you like in that will persist across
# the events execution.
#
# You can also access the instances of middleware themselves by `state[MyMiddleware]`.
#
# Event attributes can be specified *after* your middleware chain, and they
# will be evaluated *before* your middleware.
# @example Basic custom middleware usage
#   class Prefix
#     def initialize(prefix)
#       @prefix = prefix
#     end
#
#     def call(event, _state)
#       # Only continue if the message starts with our prefix
#       yield if event.message.content.start_with?(@prefix)
#     end
#   end
#
#   class RandomNumber
#     def call(event, state)
#       # Store a random number to access later
#       state[:number] = rand(1..10)
#       yield
#     end
#   end
#
#   # Filter on messages in a channel named "general" that start with "!":
#   bot.message(Prefix.new('!'), RandomNumber.new, in: 'general') do |event, state|
#     command = event.message.content.split(' ').first
#     case command
#     when '!ping'
#       event.respond('pong')
#     when '!random'
#       # Access our `:number` that `RandomNumber` set for this event:
#       event.respond("Random number: #{state[:number]}")
#     else
#       event.repond("Unknown command, try `!ping` or `!random`")
#     end
#   end
# @example Middleware-only event handler
#   class RandomWord
#     def initialize(*words)
#       @words = words
#     end
#
#     def call(event, _state)
#       event.respond(@words.sample)
#     end
#   end
#
#   bot.message(RandomWord.new('Go to bed', 'Write more Ruby bots'),
#               starts_with: '!random')
# @note **This is an opt-in, unstable preview module.** Future releases may see
#  large breaking changes to this module as it is integrated into the rest of
#  the library. You can `require "discordrb/middleware"` to use it.
module Discordrb::Middleware
  # Internal class that holds a chain of middleware.
  # @!visibility private
  class Stack
    def initialize(middleware)
      @middleware = middleware
    end

    # Runs an event object across this chain of middleware and optional block
    def run(event, state = {}, index = 0, &block)
      middleware = @middleware[index]
      if middleware
        state[middleware.class] = middleware
        middleware.call(event, state) { run(event, state, index + 1, &block) }
      elsif block_given?
        yield event, state
      end
    end
  end

  # Internal class that allows `Stack` instances to be used inside of a `Bot`s
  # event loop.
  # @!visibility private
  class Handler
    def initialize(stack, block)
      @stack = stack
      @block = block
    end

    # Conditional event matching is handled by middleware themselves,
    # so a `Handler` matches on all events.
    def matches?(_event)
      true
    end

    # Executes the stack with the given event
    def call(event)
      @stack.run(event, &@block)
    end

    # TODO: Make some use of this?
    def after_call(event); end
  end

  # A stock middleware that allows usage of event handler classes from `Events`
  # to be used in middleware chains.
  # @!visibility private
  class HandlerMiddleware
    def initialize(handler)
      @handler = handler
    end

    # Handle events
    def call(event, _state)
      yield if @handler.matches?(event)
    end
  end

  # Module for describing stock middleware handlers and generating middleware
  # chains from a hash. This can be used to extend the default event handler
  # attributes with custom ones.
  # @example Add a role name attribute to `bot.reaction_add`
  #   Discordrb::Middleware::Stock.register(:reaction_add, :role_name) do |value|
  #     lambda do |event, _state, &block|
  #       roles = event.user.roles.map(&:name)
  #       block.call if roles.include?(value)
  #     end
  #   end
  #
  #   bot.message(role_name: 'No Reactions') do |event|
  #     event.message.delete_reaction(event.user, event.emoji)
  #   end
  module Stock
    @middleware = Hash.new { |hash, key| hash[key] = {} }

    # Registers a new attribute for a particular event handler type
    # @param name [Symbol] the name of the event handler to support (`:message`, `:member_join`)
    # @param attribute [Symbol] desired name of the attribute
    # @yield [value] the value passed into the event handler attribute
    # @yieldreturn [#call(event, state, &block)] the middleware instance as configured with `value`
    def self.register(name, attribute, &block)
      @middleware[name][attribute] = block
    end

    # Retrieves an array of middleware as registered under the given name and attributes
    # @param name [Symbol] the name of the event handler
    # @param attributes [Hash] the attributes to instantiate middleware for this handler with
    # @return [Array<#call>] the configured middleware
    # @raise [ArgumentError] if an unknown attribute is specified
    def self.get(name, **attributes)
      attributes.map do |key, value|
        middleware = @middleware[name][key]

        raise(ArgumentError, <<~HERE) unless middleware
          Attribute #{key.inspect} (given with value #{value.inspect}) doesn't exist for #{name} event handlers.
          Options are: #{@middleware[name].keys}
        HERE

        middleware.call(value)
      end
    end
  end

  class << self
    # @!macro [attach] event_handler
    #   @method $1(*middleware, **attributes, &block)
    #     Registers an {$2} event handler.
    #     @param [Array<#call>] middleware a list of objects that respond to `#call(event, state, &block)`
    #     @param [Hash] attributes attributes to match for this event (See {EventContainer#$1})
    # @!visibility private
    def event_handler(name, klass)
      define_method(name) do |*middleware, **attributes, &block|
        middleware.each do |mw|
          raise ArgumentError, "Middleware #{mw} does not repsond to `#call(event, state, &block)`" unless mw.respond_to?(:call)
        end

        stock_middleware = Stock.get(name, attributes) || begin
          # TODO: Remove once all events implemented under Stock
          handler = Discordrb::EventContainer.handler_class(klass).new(attributes, nil)
          HandlerMiddleware.new(handler)
        end

        stack = Stack.new(Array(stock_middleware) + middleware)
        handler = Handler.new(stack, block)
        (event_handlers[klass] ||= []) << handler
        handler
      end
    end
  end

  # @return [Hash<Event => Array<Handler>>] the event handlers registered on this bot
  def event_handlers
    @event_handlers ||= {}
  end

  event_handler :message, Discordrb::Events::MessageEvent

  event_handler :ready, Discordrb::Events::ReadyEvent

  event_handler :disconnected, Discordrb::Events::DisconnectEvent

  event_handler :heartbeat, Discordrb::Events::HeartbeatEvent

  event_handler :typing, Discordrb::Events::TypingEvent

  event_handler :message_edit, Discordrb::Events::MessageEditEvent

  event_handler :message_delete, Discordrb::Events::MessageDeleteEvent

  event_handler :reaction_add, Discordrb::Events::ReactionAddEvent

  event_handler :reaction_remove, Discordrb::Events::ReactionRemoveEvent

  event_handler :reaction_remove_all, Discordrb::Events::ReactionRemoveAllEvent

  event_handler :presence, Discordrb::Events::PresenceEvent

  event_handler :playing, Discordrb::Events::PlayingEvent

  event_handler :mention, Discordrb::Events::MentionEvent

  event_handler :channel_create, Discordrb::Events::ChannelCreateEvent

  event_handler :channel_update, Discordrb::Events::ChannelUpdateEvent

  event_handler :channel_delete, Discordrb::Events::ChannelDeleteEvent

  event_handler :channel_recipient_add, Discordrb::Events::ChannelRecipientAddEvent

  event_handler :channel_recipient_remove, Discordrb::Events::ChannelRecipientRemoveEvent

  event_handler :voice_state_update, Discordrb::Events::VoiceStateUpdateEvent

  event_handler :member_join, Discordrb::Events::ServerMemberAddEvent

  event_handler :member_update, Discordrb::Events::ServerMemberUpdateEvent

  event_handler :member_leave, Discordrb::Events::ServerMemberDeleteEvent

  event_handler :user_ban, Discordrb::Events::UserBanEvent

  event_handler :user_unban, Discordrb::Events::UserUnbanEvent

  event_handler :server_create, Discordrb::Events::ServerCreateEvent

  event_handler :server_update, Discordrb::Events::ServerUpdateEvent

  event_handler :server_delete, Discordrb::Events::ServerDeleteEvent

  event_handler :server_emoji, Discordrb::Events::ServerEmojiChangeEvent

  event_handler :server_emoji_create, Discordrb::Events::ServerEmojiCreateEvent

  event_handler :server_emoji_delete, Discordrb::Events::ServerEmojiDeleteEvent

  event_handler :server_emoji_update, Discordrb::Events::ServerEmojiUpdateEvent

  event_handler :webhook_update, Discordrb::Events::WebhookUpdateEvent

  event_handler :pm, Discordrb::Events::PrivateMessageEvent

  event_handler :raw, Discordrb::Events::RawEvent

  event_handler :unknown, Discordrb::Events::UnknownEvent
end

# Require stock middlewares
require 'discordrb/middleware/message'

# TODO: Remove when middleware is stabilized
Discordrb::Bot.include(Discordrb::Middleware)
