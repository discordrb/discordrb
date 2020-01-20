# frozen_string_literal: true

module Discordrb
  # Awaits are a way to register new, temporary event handlers on the fly. Awaits can be
  # registered using {Bot#add_await}, {User#await}, {Message#await} and {Channel#await}.
  #
  # Awaits contain a block that will be called before the await event will be triggered.
  # If this block returns anything that is not `false` exactly, the await will be deleted.
  # If no block is present, the await will also be deleted. This is an easy way to make
  # temporary events that are only temporary under certain conditions.
  #
  # Besides the given block, an {Discordrb::Events::AwaitEvent} will also be executed with the key and
  # the type of the await that was triggered. It's possible to register multiple events
  # that trigger on the same await.
  class Await
    # The key that uniquely identifies this await.
    # @return [Symbol] The unique key.
    attr_reader :key

    # The class of the event that this await listens for.
    # @return [Class] The event class.
    attr_reader :type

    # The attributes of the event that will be listened for.
    # @return [Hash] A hash of attributes.
    attr_reader :attributes

    # Makes a new await. For internal use only.
    # @!visibility private
    def initialize(bot, key, type, attributes, block = nil)
      @bot = bot
      @key = key
      @type = type
      @attributes = attributes
      @block = block
    end

    # Checks whether the await can be triggered by the given event, and if it can, execute the block
    # and return its result along with this await's key.
    # @param event [Event] An event to check for.
    # @return [Array] This await's key and whether or not it should be deleted. If there was no match, both are nil.
    def match(event)
      dummy_handler = EventContainer.handler_class(@type).new(@attributes, @bot)
      return [nil, nil] unless event.instance_of?(@type) && dummy_handler.matches?(event)

      should_delete = true if (@block && @block.call(event) != false) || !@block

      [@key, should_delete]
    end
  end
end
