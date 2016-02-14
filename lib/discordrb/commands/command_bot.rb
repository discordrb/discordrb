require 'discordrb/bot'
require 'discordrb/data'
require 'discordrb/commands/parser'
require 'discordrb/commands/events'
require 'discordrb/commands/container'
require 'discordrb/commands/rate_limiter'

# Specialized bot to run commands

module Discordrb::Commands
  # Bot that supports commands and command chains
  class CommandBot < Discordrb::Bot
    attr_reader :attributes, :prefix

    include CommandContainer

    # Creates a new CommandBot and logs in to Discord.
    # @param email [String] The email to use to log in.
    # @param password [String] The password corresponding to the email.
    # @param prefix [String] The prefix that should trigger this bot's commands. Can be any string (including the empty
    #   string), but note that it will be literal - if the prefix is "hi" then the corresponding trigger string for
    #   a command called "test" would be "hitest". Don't forget to put spaces in if you need them!
    # @param attributes [Hash] The attributes to initialize the CommandBot with.
    # @param debug [true, false] Whether or not debug mode should be used - debug mode logs tons of extra stuff to the
    #   console that may be useful in development.
    # @option attributes [true, false] :advanced_functionality Whether to enable advanced functionality (very powerful
    #   way to nest commands into chains, see https://github.com/meew0/discordrb/wiki/Commands#command-chain-syntax
    #   for info. Default is true.
    # @option attributes [Symbol, Array<Symbol>] :help_command The name of the command that displays info for other
    #   commands. Use an array if you want to have aliases. Default is "help".
    # @option attributes [String] :command_doesnt_exist_message The message that should be displayed if a user attempts
    #   to use a command that does not exist. If none is specified, no message will be displayed. In the message, you
    #   can use the string '%command%' that will be replaced with the name of the command.
    # @option attributes [String] :previous Character that should designate the result of the previous command in
    #   a command chain (see :advanced_functionality). Default is '~'.
    # @option attributes [String] :chain_delimiter Character that should designate that a new command begins in the
    #   command chain (see :advanced_functionality). Default is '>'.
    # @option attributes [String] :chain_args_delim Character that should separate the command chain arguments from the
    #   chain itself (see :advanced_functionality). Default is ':'.
    # @option attributes [String] :sub_chain_start Character that should start a sub-chain (see
    #   :advanced_functionality). Default is '['.
    # @option attributes [String] :sub_chain_end Character that should end a sub-chain (see
    #   :advanced_functionality). Default is ']'.
    # @option attributes [String] :quote_start Character that should start a quoted string (see
    #   :advanced_functionality). Default is '"'.
    # @option attributes [String] :quote_end Character that should end a quoted string (see
    #   :advanced_functionality). Default is '"'.
    def initialize(email, password, prefix, attributes = {}, debug = false)
      super(email, password, debug)
      @prefix = prefix
      @attributes = {
        # Whether advanced functionality such as command chains are enabled
        advanced_functionality: attributes[:advanced_functionality].nil? ? true : attributes[:advanced_functionality],

        # The name of the help command (that displays information to other commands). Nil if none should exist
        help_command: attributes[:help_command] || :help,

        # The message to display for when a command doesn't exist, %command% to get the command name in question and nil for no message
        # No default value here because it may not be desired behaviour
        command_doesnt_exist_message: attributes[:command_doesnt_exist_message],

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

    # Executes a particular command on the bot. Mostly useful for internal stuff, but one can never know.
    # @param name [Symbol] The command to execute.
    # @param event [CommandEvent] The event to pass to the command.
    # @param arguments [Array<String>] The arguments to pass to the command.
    # @param chained [true, false] Whether or not it should be executed as part of a command chain. If this is false,
    #   commands that have chain_usable set to false will not work.
    # @return [String, nil] the command's result, if there is any.
    def execute_command(name, event, arguments, chained = false)
      debug("Executing command #{name} with arguments #{arguments}")
      command = @commands[name]
      unless command
        event.respond @attributes[:command_doesnt_exist_message].gsub('%command%', name.to_s) if @attributes[:command_doesnt_exist_message]
        return
      end
      if permission?(user(event.user.id), command.attributes[:permission_level], event.server)
        event.command = command
        result = command.call(event, arguments, chained)
        result.to_s
      else
        event.respond "You don't have permission to execute command `#{name}`!"
      end
    end

    # Executes a command in a simple manner, without command chains or permissions.
    # @param chain [String] The command with its arguments separated by spaces.
    # @param event [CommandEvent] The event to pass to the command.
    # @return [String, nil] the command's result, if there is any.
    def simple_execute(chain, event)
      return nil if chain.empty?
      args = chain.split(' ')
      execute_command(args[0].to_sym, event, args[1..-1])
    end

    # Sets the permission level of a user
    # @param id [Integer] the ID of the user whose level to set
    # @param level [Integer] the level to set the permission to
    def set_user_permission(id, level)
      @permissions[:users][id] = level
    end

    # Sets the permission level of a role - this applies to all users in the role
    # @param id [Integer] the ID of the role whose level to set
    # @param level [Integer] the level to set the permission to
    def set_role_permission(id, level)
      @permissions[:roles][id] = level
    end

    # Check if a user has permission to do something
    # @param user [User] The user to check
    # @param level [Integer] The minimum permission level the user should have (inclusive)
    # @param server [Server] The server on which to check
    # @return [true, false] whether or not the user has the given permission
    def permission?(user, level, server)
      determined_level = server.nil? ? 0 : user.roles[server.id].each.reduce(0) do |memo, role|
        [@permissions[:roles][role.id] || 0, memo].max
      end
      [@permissions[:users][user.id] || 0, determined_level].max >= level
    end

    private

    # Internal handler for MESSAGE_CREATE that is overwritten to allow for command handling
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
          event.respond result unless result.nil? || result.empty?
        rescue => e
          log_exception(e)
        ensure
          @event_threads.delete(t)
        end
      end
    end
  end
end
