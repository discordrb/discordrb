module Discordrb
  # Class that represents an await to wait for a further event
  class Await
    attr_reader :key, :type, :attributes

    def initialize(bot, key, type, attributes, block = nil)
      @bot = bot
      @key = key
      @type = type
      @attributes = attributes
      @block = block
    end

    def match(event)
      dummy_handler = @bot.handler_class(@type).new(@attributes, @bot)
      return [nil, nil] unless dummy_handler.matches?(event)

      should_delete = true if @block.call(event) != false || !block

      [@key, should_delete]
    end
  end
end
