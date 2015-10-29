require 'discordrb/bot'
require 'discordrb/commands/parser'

# Specialized bot to run commands

module Discordrb::Commands
  class CommandBot < Bot
    attr_reader :attributes, :prefix

    def initialize(email, password, prefix, attributes = {}, debug = false)
      super(email, password, debug)
      @prefix = prefix
      @commands = {}
      @attributes = {
        # Whether advanced functionality such as command chains are enabled
        advanced_functionality: attributes[:advanced_functionality].nil? ? true : attributes[:advanced_functionality],

        # All of the following need to be one character
        # String to designate previous result in command chain
        previous: attributes[:previous] || '~',

        # Command chain delimiter
        chain_delimiter: attributes[:chain_delimiter] || '>',

        # Chain argument delimiter
        chain_args_delim: attributes[:chain_args_delim] || ':',

        # Sub-chain starting character
        sub_chain_start: attributes[:sub_chain_start] || '[',

        # Sub-chain ending character
        sub_chain_end: attributes[:sub_chain_end] || ']',

        # Quoted mode starting character
        quote_start: attributes[:quote_start] || "'",

        # Quoted mode ending character
        quote_end: attributes[:quote_end] || "'"
      }
    end

    def command(name, attributes = {}, &block)
      @commands[name] = Command.new(name, attributes, &block)
    end

    def execute_command(name, event, arguments)
      command = @commands[name]
      command.call(event, arguments)
    end

    def create_message(data)
      message = Message.new(data, self)
      event = MessageEvent.new(message, self)

      if message.content.start_with? @prefix
        chain = message.content[@prefix.length..-1]
        CommandChain.new(chain, self, true).execute(event)
      end
    end
  end
end
