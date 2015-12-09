require 'discordrb/events/message'

module Discordrb::Commands
  # Extension of MessageEvent for commands that contains the command called, makes the bot readable and adds a message to be saved
  class CommandEvent < Discordrb::Events::MessageEvent
    attr_reader :bot, :saved_message
    attr_accessor :command

    def initialize(message, bot)
      super(message, bot)
      @saved_message = ''
    end

    def <<(message)
      @saved_message += "#{message}\n"
      nil
    end
  end
end
