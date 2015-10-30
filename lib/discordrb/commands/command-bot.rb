require 'discordrb/bot'
require 'discordrb/commands/parser'

# Specialized bot to run commands

module Discordrb::Commands
  class CommandBot < Discordrb::Bot
    attr_reader :attributes, :prefix

    def initialize(email, password, prefix, attributes = {}, debug = false)
      super(email, password, debug)
      @prefix = prefix
      @commands = {}
      @attributes = {
        # Whether advanced functionality such as command chains are enabled
        advanced_functionality: attributes[:advanced_functionality].nil? ? true : attributes[:advanced_functionality],

        # The name of the help command (that displays information to other commands). Nil if none should exist
        help_command: attributes[:help_command] || :help,

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

      if @attributes[:help_command]
        command(@attributes[:help_command], max_args: 1, description: 'Shows a list of all the commands available or displays help for a specific command.', usage: 'help [command name]') do |event, command_name|
          if command_name
            command = @commands[command_name.to_sym]
            unless command
              return "The command `#{command_name}` does not exist!"
            end
            desc = command.attributes[:description] || '*No description available*'
            usage = command.attributes[:usage]
            result = "**`#{command_name}`**: #{desc}"
            result << "\nUsage: `#{usage}`" if usage
          else
            available_commands = @commands.values.reject { |command| !command.attributes[:help_available] }
            case available_commands.length
            when 0..5
              available_commands.reduce "**List of commands:**\n" do |memo, command|
                memo + "**`#{command.name}`**: #{command.attributes[:description] || '*No description available*'}\n"
              end
            when 5..50
              (available_commands.reduce "**List of commands:**\n" do |memo, command|
                memo + "`#{command.name}`, "
              end)[0..-3]
            else
              event.user.pm (available_commands.reduce "**List of commands:**\n" do |memo, command|
                memo + "`#{command.name}`, "
              end)[0..-3]
              "Sending list in PM!"
            end
          end
        end
      end
    end

    def command(name, attributes = {}, &block)
      @commands[name] = Command.new(name, attributes, &block)
    end

    def execute_command(name, event, arguments, chained = false)
      debug("Executing command #{name} with arguments #{arguments}")
      command = @commands[name]
      unless command
        event.respond "The command `#{name}` doesn't exist!"
        return
      end
      command.call(event, arguments, chained)
    end

    def create_message(data)
      message = Discordrb::Message.new(data, self)
      event = Discordrb::Events::MessageEvent.new(message, self)

      if message.content.start_with? @prefix
        chain = message.content[@prefix.length..-1]
        debug("Parsing command chain #{chain}")
        result = CommandChain.new(chain, self).execute(event)
        event.respond result if result
      end
    end
  end
end
