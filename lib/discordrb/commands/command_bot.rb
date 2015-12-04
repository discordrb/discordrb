require 'discordrb/bot'
require 'discordrb/data'
require 'discordrb/commands/parser'
require 'discordrb/commands/events'

# Specialized bot to run commands

module Discordrb::Commands
  # Bot that supports commands and command chains
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

        # The message to display for when a command doesn't exist, %command% to get the command name in question and nil for no message
        command_doesnt_exist_message: attributes[:command_doesnt_exist_message] || "The command `%command%` doesn't exist!",

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
        quote_start: attributes[:quote_start] || '"',

        # Quoted mode ending character
        quote_end: attributes[:quote_end] || '"'
      }

      @permissions = {
        roles: {},
        users: {}
      }

      return unless @attributes[:help_command]
      command(@attributes[:help_command], max_args: 1, description: 'Shows a list of all the commands available or displays help for a specific command.', usage: 'help [command name]') do |event, command_name|
        if command_name
          command = @commands[command_name.to_sym]
          return "The command `#{command_name}` does not exist!" unless command
          desc = command.attributes[:description] || '*No description available*'
          usage = command.attributes[:usage]
          result = "**`#{command_name}`**: #{desc}"
          result << "\nUsage: `#{usage}`" if usage
        else
          available_commands = @commands.values.reject { |c| !c.attributes[:help_available] }
          case available_commands.length
          when 0..5
            available_commands.reduce "**List of commands:**\n" do |memo, c|
              memo + "**`#{c.name}`**: #{c.attributes[:description] || '*No description available*'}\n"
            end
          when 5..50
            (available_commands.reduce "**List of commands:**\n" do |memo, c|
              memo + "`#{c.name}`, "
            end)[0..-3]
          else
            event.user.pm(available_commands.reduce("**List of commands:**\n") { |a, e| a + "`#{e.name}`, " })[0..-3]
            'Sending list in PM!'
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
        event.respond @attributes[:command_doesnt_exist_message].gsub('%command%', name.to_s) if @attributes[:command_doesnt_exist_message]
        return
      end
      if permission?(user(event.user.id), command.attributes[:permission_level], event.server)
        event.command = command
        command.call(event, arguments, chained)
      else
        event.respond "You don't have permission to execute command `#{name}`!"
        return
      end
    end

    def simple_execute(chain, event)
      return nil if chain.empty?
      args = chain.split(' ')
      execute_command(args[0].to_sym, event, args[1..-1])
    end

    def create_message(data)
      message = Discordrb::Message.new(data, self)
      event = CommandEvent.new(message, self)

      return unless message.content.start_with? @prefix
      chain = message.content[@prefix.length..-1]

      if chain.strip.empty?
        debug('Chain is empty')
        return
      end

      execute_chain(chain, event)
    end

    def execute_chain(chain, event)
      t = Thread.new do
        @event_threads << t
        Thread.current[:discordrb_name] = "ct-#{@current_thread += 1}"
        begin
          debug("Parsing command chain #{chain}")
          result = (@attributes[:advanced_functionality]) ? CommandChain.new(chain, self).execute(event) : simple_execute(chain, event)
          result = event.saved_message + (result || '')
          event.respond result if result
        rescue => e
          log_exception(e)
        ensure
          @event_threads.delete(t)
        end
      end
    end

    def set_user_permission(id, level)
      @permissions[:users][id] = level
    end

    def set_role_permission(id, level)
      @permissions[:roles][id] = level
    end

    def permission?(user, level, server)
      determined_level = server.nil? ? 0 : user.roles[server.id].each.reduce(0) do |memo, role|
        [@permissions[:roles][role.id] || 0, memo].max
      end
      [@permissions[:users][user.id] || 0, determined_level].max >= level
    end
  end
end
