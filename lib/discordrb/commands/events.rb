# frozen_string_literal: true

require 'discordrb/events/message'

module Discordrb::Commands
  # Extension of MessageEvent for commands that contains the command called and makes the bot readable
  class CommandEvent < Discordrb::Events::MessageEvent
    attr_reader :bot
    attr_accessor :command
  end
end
