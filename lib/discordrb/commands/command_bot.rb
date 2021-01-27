# frozen_string_literal: true

require 'discordrb/bot'
require 'discordrb/data'
require 'discordrb/commands/parser'
require 'discordrb/commands/events'
require 'discordrb/commands/container'
require 'discordrb/commands/rate_limiter'
require 'time'

# Specialized bot to run commands

module Discordrb::Commands
  # Bot that supports commands and command chains
  class CommandBot < Discordrb::Bot
    # @return [Hash] this bot's attributes.
    attr_reader :attributes

    # @return [String, Array<String>, #call] the prefix commands are triggered with.
    # @see #initialize
    attr_reader :prefix

    include CommandContainer

    # Creates a new CommandBot and logs in to Discord.
    # @param attributes [Hash] The attributes to initialize the CommandBot with.
    # @see Discordrb::Bot#initialize Discordrb::Bot#initialize for other attributes that should be used to create the underlying regular bot.
    # @option attributes [String, Array<String>, #call] :prefix The prefix that should trigger this bot's commands. It
    #   can be:
    #
    #   * Any string (including the empty string). This has the effect that if a message starts with the prefix, the
    #     prefix will be stripped and the rest of the chain will be parsed as a command chain. Note that it will be
    #     literal - if the prefix is "hi" then the corresponding trigger string for a command called "test" would be
    #     "hitest". Don't forget to put spaces in if you need them!
    #   * An array of prefixes. Those will behave similarly to setting one string as a prefix, but instead of only one
    #     string, any of the strings in the array can be used.
    #   * Something Proc-like (responds to :call) that takes a {Message} object as an argument and returns either
    #     the command chain in raw form or `nil` if the given message shouldn't be parsed. This can be used to make more
    #     complicated dynamic prefixes (e. g. based on server), or even something else entirely (suffixes, or most
    #     adventurous, infixes).
    # @option attributes [true, false] :advanced_functionality Whether to enable advanced functionality (very powerful
    #   way to nest commands into chains, see https://github.com/shardlab/discordrb/wiki/Commands#command-chain-syntax
    #   for info. Default is false.
    # @option attributes [Symbol, Array<Symbol>, false] :help_command The name of the command that displays info for
    #   other commands. Use an array if you want to have aliases. Default is "help". If none should be created, use
    #   `false` as the value.
    # @option attributes [String, #call] :command_doesnt_exist_message The message that should be displayed if a user attempts
    #   to use a command that does not exist. If none is specified, no message will be displayed. In the message, you
    #   can use the string '%command%' that will be replaced with the name of the command. Anything responding to call
    #   such as a proc will be called with the event, and is expected to return a String or nil.
    # @option attributes [String] :no_permission_message The message to be displayed when `NoPermission` error is raised.
    # @option attributes [true, false] :spaces_allowed Whether spaces are allowed to occur between the prefix and the
    #   command. Default is false.
    # @option attributes [true, false] :webhook_commands Whether messages sent by webhooks are allowed to trigger
    #   commands. Default is true.
    # @option attributes [Array<String, Integer, Channel>] :channels The channels this command bot accepts commands on.
    #   Superseded if a command has a 'channels' attribute.
    # @option attributes [String] :previous Character that should designate the result of the previous command in
    #   a command chain (see :advanced_functionality). Default is '~'. Set to an empty string to disable.
    # @option attributes [String] :chain_delimiter Character that should designate that a new command begins in the
    #   command chain (see :advanced_functionality). Default is '>'. Set to an empty string to disable.
    # @option attributes [String] :chain_args_delim Character that should separate the command chain arguments from the
    #   chain itself (see :advanced_functionality). Default is ':'. Set to an empty string to disable.
    # @option attributes [String] :sub_chain_start Character that should start a sub-chain (see
    #   :advanced_functionality). Default is '['. Set to an empty string to disable.
    # @option attributes [String] :sub_chain_end Character that should end a sub-chain (see
    #   :advanced_functionality). Default is ']'. Set to an empty string to disable.
    # @option attributes [String] :quote_start Character that should start a quoted string (see
    #   :advanced_functionality). Default is '"'. Set to an empty string to disable.
    # @option attributes [String] :quote_end Character that should end a quoted string (see
    #   :advanced_functionality). Default is '"' or the same as :quote_start. Set to an empty string to disable.
    # @option attributes [true, false] :ignore_bots Whether the bot should ignore bot accounts or not. Default is false.
    def initialize(attributes = {})
      super(
        log_mode: attributes[:log_mode],
        token: attributes[:token],
        client_id: attributes[:client_id],
        type: attributes[:type],
        name: attributes[:name],
        fancy_log: attributes[:fancy_log],
        suppress_ready: attributes[:suppress_ready],
        parse_self: attributes[:parse_self],
        shard_id: attributes[:shard_id],
        num_shards: attributes[:num_shards],
        redact_token: attributes.key?(:redact_token) ? attributes[:redact_token] : true,
        ignore_bots: attributes[:ignore_bots],
        compress_mode: attributes[:compress_mode],
        intents: attributes[:intents]
      )

      @prefix = attributes[:prefix]
      @attributes = {
        # Whether advanced functionality such as command chains are enabled
        advanced_functionality: attributes[:advanced_functionality].nil? ? false : attributes[:advanced_functionality],

        # The name of the help command (that displays information to other commands). False if none should exist
        help_command: attributes[:help_command].is_a?(FalseClass) ? nil : (attributes[:help_command] || :help),

        # The message to display for when a command doesn't exist, %command% to get the command name in question and nil for no message
        # No default value here because it may not be desired behaviour
        command_doesnt_exist_message: attributes[:command_doesnt_exist_message],

        # The message to be displayed when `NoPermission` error is raised.
        no_permission_message: attributes[:no_permission_message],

        # Spaces allowed between prefix and command
        spaces_allowed: attributes[:spaces_allowed].nil? ? false : attributes[:spaces_allowed],

        # Webhooks allowed to trigger commands
        webhook_commands: attributes[:webhook_commands].nil? ? true : attributes[:webhook_commands],

        channels: attributes[:channels] || [],

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
        quote_end: attributes[:quote_end] || attributes[:quote_start] || '"',

        # Default block for handling internal exceptions, or a string to respond with
        rescue: attributes[:rescue]
      }

      @permissions = {
        roles: {},
        users: {}
      }

      return unless @attributes[:help_command]

      command(@attributes[:help_command], max_args: 1, description: 'Shows a list of all the commands available or displays help for a specific command.', usage: 'help [command name]') do |event, command_name|
        if command_name
          command = @commands[command_name.to_sym]
          if command.is_a?(CommandAlias)
            command = command.aliased_command
            command_name = command.name
          end
          return "The command `#{command_name}` does not exist!" unless command

          desc = command.attributes[:description] || '*No description available*'
          usage = command.attributes[:usage]
          parameters = command.attributes[:parameters]
          result = "**`#{command_name}`**: #{desc}"
          aliases = command_aliases(command_name.to_sym)
          unless aliases.empty?
            result += "\nAliases: "
            result += aliases.map { |a| "`#{a.name}`" }.join(', ')
          end
          result += "\nUsage: `#{usage}`" if usage
          if parameters
            result += "\nAccepted Parameters:\n```"
            parameters.each { |p| result += "\n#{p}" }
            result += '```'
          end
          result
        else
          available_commands = @commands.values.reject do |c|
            c.is_a?(CommandAlias) || !c.attributes[:help_available] || !required_roles?(event.user, c.attributes[:required_roles]) || !allowed_roles?(event.user, c.attributes[:allowed_roles]) || !required_permissions?(event.user, c.attributes[:required_permissions], event.channel)
          end
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
            event.user.pm(available_commands.reduce("**List of commands:**\n") { |m, e| m + "`#{e.name}`, " }[0..-3])
            event.channel.pm? ? '' : 'Sending list in PM!'
          end
        end
      end
    end

    # Returns all aliases for the command with the given name
    # @param name [Symbol] the name of the `Command`
    # @return [Array<CommandAlias>]
    def command_aliases(name)
      commands.values.select do |command|
        command.is_a?(CommandAlias) && command.aliased_command.name == name
      end
    end

    # Executes a particular command on the bot. Mostly useful for internal stuff, but one can never know.
    # @param name [Symbol] The command to execute.
    # @param event [CommandEvent] The event to pass to the command.
    # @param arguments [Array<String>] The arguments to pass to the command.
    # @param chained [true, false] Whether or not it should be executed as part of a command chain. If this is false,
    #   commands that have chain_usable set to false will not work.
    # @param check_permissions [true, false] Whether permission parameters such as `required_permission` or
    #   `permission_level` should be checked.
    # @return [String, nil] the command's result, if there is any.
    def execute_command(name, event, arguments, chained = false, check_permissions = true)
      debug("Executing command #{name} with arguments #{arguments}")
      return unless @commands

      command = @commands[name]
      command = command.aliased_command if command.is_a?(CommandAlias)
      return unless !check_permissions || channels?(event.channel, @attributes[:channels]) ||
                    (command && !command.attributes[:channels].nil?)

      unless command
        if @attributes[:command_doesnt_exist_message]
          message = @attributes[:command_doesnt_exist_message]
          message = message.call(event) if message.respond_to?(:call)
          event.respond message.gsub('%command%', name.to_s) if message
        end
        return
      end
      return unless !check_permissions || channels?(event.channel, command.attributes[:channels])

      arguments = arg_check(arguments, command.attributes[:arg_types], event.server) if check_permissions
      if (check_permissions &&
         permission?(event.author, command.attributes[:permission_level], event.server) &&
         required_permissions?(event.author, command.attributes[:required_permissions], event.channel) &&
         required_roles?(event.author, command.attributes[:required_roles]) &&
         allowed_roles?(event.author, command.attributes[:allowed_roles])) ||
         !check_permissions
        event.command = command
        result = command.call(event, arguments, chained, check_permissions)
        stringify(result)
      else
        event.respond command.attributes[:permission_message].gsub('%name%', name.to_s) if command.attributes[:permission_message]
        nil
      end
    rescue Discordrb::Errors::NoPermission
      event.respond @attributes[:no_permission_message] unless @attributes[:no_permission_message].nil?
      raise
    end

    # Transforms an array of string arguments based on types array.
    # For example, `['1', '10..14']` with types `[Integer, Range]` would turn into `[1, 10..14]`.
    def arg_check(args, types = nil, server = nil)
      return args unless types

      args.each_with_index.map do |arg, i|
        next arg if types[i].nil? || types[i] == String

        if types[i] == Integer
          begin
            Integer(arg, 10)
          rescue ArgumentError
            nil
          end
        elsif types[i] == Float
          begin
            Float(arg)
          rescue ArgumentError
            nil
          end
        elsif types[i] == Time
          begin
            Time.parse arg
          rescue ArgumentError
            nil
          end
        elsif types[i] == TrueClass || types[i] == FalseClass
          if arg.casecmp('true').zero? || arg.downcase.start_with?('y')
            true
          elsif arg.casecmp('false').zero? || arg.downcase.start_with?('n')
            false
          end
        elsif types[i] == Symbol
          arg.to_sym
        elsif types[i] == Encoding
          begin
            Encoding.find arg
          rescue ArgumentError
            nil
          end
        elsif types[i] == Regexp
          begin
            Regexp.new arg
          rescue ArgumentError
            nil
          end
        elsif types[i] == Rational
          begin
            Rational(arg)
          rescue ArgumentError
            nil
          end
        elsif types[i] == Range
          begin
            if arg.include? '...'
              Range.new(*arg.split('...').map(&:to_i), true)
            elsif arg.include? '..'
              Range.new(*arg.split('..').map(&:to_i))
            end
          rescue ArgumentError
            nil
          end
        elsif types[i] == NilClass
          nil
        elsif [Discordrb::User, Discordrb::Role, Discordrb::Emoji].include? types[i]
          result = parse_mention arg, server
          result if result.instance_of? types[i]
        elsif types[i] == Discordrb::Invite
          resolve_invite_code arg
        elsif types[i].respond_to?(:from_argument)
          begin
            types[i].from_argument arg
          rescue StandardError
            nil
          end
        else
          raise ArgumentError, "#{types[i]} doesn't implement from_argument"
        end
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
      determined_level = if user.webhook? || server.nil?
                           0
                         else
                           user.roles.reduce(0) do |memo, role|
                             [@permissions[:roles][role.id] || 0, memo].max
                           end
                         end

      [@permissions[:users][user.id] || 0, determined_level].max >= level
    end

    # @see CommandBot#update_channels
    def channels=(channels)
      update_channels(channels)
    end

    # Update the list of channels the bot accepts commands from.
    # @param channels [Array<String, Integer, Channel>] The channels this command bot accepts commands on.
    def update_channels(channels = [])
      @attributes[:channels] = Array(channels)
    end

    # Add a channel to the list of channels the bot accepts commands from.
    # @param channel [String, Integer, Channel] The channel name, integer ID, or `Channel` object to be added
    def add_channel(channel)
      return if @attributes[:channels].find { |c| channel.resolve_id == c.resolve_id }

      @attributes[:channels] << channel
    end

    # Remove a channel from the list of channels the bot accepts commands from.
    # @param channel [String, Integer, Channel] The channel name, integer ID, or `Channel` object to be removed
    def remove_channel(channel)
      @attributes[:channels].delete_if { |c| channel.resolve_id == c.resolve_id }
    end

    private

    # Internal handler for MESSAGE_CREATE that is overwritten to allow for command handling
    def create_message(data)
      message = Discordrb::Message.new(data, self)
      return message if message.from_bot? && !@should_parse_self
      return message if message.webhook? && !@attributes[:webhook_commands]

      unless message.author
        Discordrb::LOGGER.warn("Received a message (#{message.inspect}) with nil author! Ignoring, please report this if you can")
        return
      end

      event = CommandEvent.new(message, self)

      chain = trigger?(message)
      return message unless chain

      # Don't allow spaces between the prefix and the command
      if chain.start_with?(' ') && !@attributes[:spaces_allowed]
        debug('Chain starts with a space')
        return message
      end

      if chain.strip.empty?
        debug('Chain is empty')
        return message
      end

      execute_chain(chain, event)

      # Return the message so it doesn't get parsed again during the rest of the dispatch handling
      message
    end

    # Check whether a message should trigger command execution, and if it does, return the raw chain
    def trigger?(message)
      if @prefix.is_a? String
        standard_prefix_trigger(message.content, @prefix)
      elsif @prefix.is_a? Array
        @prefix.map { |e| standard_prefix_trigger(message.content, e) }.reduce { |m, e| m || e }
      elsif @prefix.respond_to? :call
        @prefix.call(message)
      end
    end

    def standard_prefix_trigger(message, prefix)
      return nil unless message.start_with? prefix

      message[prefix.length..-1]
    end

    def required_permissions?(member, required, channel = nil)
      required.reduce(true) do |a, action|
        a && !member.webhook? && !member.is_a?(Discordrb::Recipient) && member.permission?(action, channel)
      end
    end

    def required_roles?(member, required)
      return true if member.webhook? || member.is_a?(Discordrb::Recipient) || required.nil? || required.empty?

      required.is_a?(Array) ? check_multiple_roles(member, required) : member.role?(role)
    end

    def allowed_roles?(member, required)
      return true if member.webhook? || member.is_a?(Discordrb::Recipient) || required.nil? || required.empty?

      required.is_a?(Array) ? check_multiple_roles(member, required, false) : member.role?(role)
    end

    def check_multiple_roles(member, required, all_roles = true)
      if all_roles
        required.all? do |role|
          member.role?(role)
        end
      else
        required.any? do |role|
          member.role?(role)
        end
      end
    end

    def channels?(channel, channels)
      return true if channels.nil? || channels.empty?

      channels.any? do |c|
        # if c is string, make sure to remove the "#" from channel names in case it was specified
        return true if c.is_a?(String) && c.delete('#') == channel.name

        c.resolve_id == channel.resolve_id
      end
    end

    def execute_chain(chain, event)
      t = Thread.new do
        @event_threads << t
        Thread.current[:discordrb_name] = "ct-#{@current_thread += 1}"
        begin
          debug("Parsing command chain #{chain}")
          result = @attributes[:advanced_functionality] ? CommandChain.new(chain, self).execute(event) : simple_execute(chain, event)
          result = event.drain_into(result)

          if event.file
            event.send_file(event.file, caption: result)
          else
            event.respond result unless result.nil? || result.empty?
          end
        rescue StandardError => e
          log_exception(e)
        ensure
          @event_threads.delete(t)
        end
      end
    end

    # Turns the object into a string, using to_s by default
    def stringify(object)
      return '' if object.is_a? Discordrb::Message

      object.to_s
    end
  end
end
