# frozen_string_literal: true

require 'discordrb/container'
require 'discordrb/commands/rate_limiter'

module Discordrb::Commands
  # This module holds a collection of commands that can be easily added to by calling the {CommandContainer#command}
  # function. Other containers can be included into it as well. This allows for modularization of command bots.
  module CommandContainer
    include RateLimiter

    # @return [Hash<Symbol, Command, CommandAlias>] hash of command names and commands this container has.
    attr_reader :commands

    # Adds a new command to the container.
    # @param name [Symbol] The name of the command to add.
    # @param attributes [Hash] The attributes to initialize the command with.
    # @option attributes [Array<Symbol>] :aliases A list of additional names for this command. This in effect
    #   creates {CommandAlias} objects in the container ({#commands}) that refer to the newly created command.
    #   Additionally, the default help command will identify these command names as an alias where applicable.
    # @option attributes [Integer] :permission_level The minimum permission level that can use this command, inclusive.
    #   See {CommandBot#set_user_permission} and {CommandBot#set_role_permission}.
    # @option attributes [String, false] :permission_message Message to display when a user does not have sufficient
    #   permissions to execute a command. %name% in the message will be replaced with the name of the command. Disable
    #   the message by setting this option to false.
    # @option attributes [Array<Symbol>] :required_permissions Discord action permissions (e.g. `:kick_members`) that
    #   should be required to use this command. See {Discordrb::Permissions::FLAGS} for a list.
    # @option attributes [Array<Role>, Array<String, Integer>] :required_roles Roles, or their IDs, that user must have to use this command
    #   (user must have all of them).
    # @option attributes [Array<Role>, Array<String, Integer>] :allowed_roles Roles, or their IDs, that user should have to use this command
    #   (user should have at least one of them).
    # @option attributes [Array<String, Integer, Channel>] :channels The channels that this command can be used on. An
    #   empty array indicates it can be used on any channel. Supersedes the command bot attribute.
    # @option attributes [true, false] :chain_usable Whether this command is able to be used inside of a command chain
    #   or sub-chain. Typically used for administrative commands that shouldn't be done carelessly.
    # @option attributes [true, false] :help_available Whether this command is visible in the help command. See the
    #   :help_command attribute of {CommandBot#initialize}.
    # @option attributes [String] :description A short description of what this command does. Will be shown in the help
    #   command if the user asks for it.
    # @option attributes [String] :usage A short description of how this command should be used. Will be displayed in
    #   the help command or if the user uses it wrong.
    # @option attributes [Array<Class>] :arg_types An array of argument classes which will be used for type-checking.
    #   Hard-coded for some native classes, but can be used with any class that implements static
    #   method `from_argument`.
    # @option attributes [Integer] :min_args The minimum number of arguments this command should have. If a user
    #   attempts to call the command with fewer arguments, the usage information will be displayed, if it exists.
    # @option attributes [Integer] :max_args The maximum number of arguments the command should have.
    # @option attributes [String] :rate_limit_message The message that should be displayed if the command hits a rate
    #   limit. None if unspecified or nil. %time% in the message will be replaced with the time in seconds when the
    #   command will be available again.
    # @option attributes [Symbol] :bucket The rate limit bucket that should be used for rate limiting. No rate limiting
    #   will be done if unspecified or nil.
    # @option attributes [String, #call] :rescue A string to respond with, or a block to be called in the event an exception
    #   is raised internally. If given a String, `%exception%` will be substituted with the exception's `#message`. If given
    #   a `Proc`, it will be passed the `CommandEvent` along with the `Exception`.
    # @yield The block is executed when the command is executed.
    # @yieldparam event [CommandEvent] The event of the message that contained the command.
    # @note `LocalJumpError`s are rescued from internally, giving bots the opportunity to use `return` or `break` in
    #   their blocks without propagating an exception.
    # @return [Command] The command that was added.
    def command(name, attributes = {}, &block)
      @commands ||= {}

      # TODO: Remove in 4.0
      if name.is_a?(Array)
        name, *aliases = name
        attributes[:aliases] = aliases if attributes[:aliases].nil?
        Discordrb::LOGGER.warn("While registering command #{name.inspect}")
        Discordrb::LOGGER.warn('Arrays for command aliases is removed. Please use `aliases` argument instead.')
      end

      new_command = Command.new(name, attributes, &block)
      new_command.attributes[:aliases].each do |aliased_name|
        @commands[aliased_name] = CommandAlias.new(aliased_name, new_command)
      end
      @commands[name] = new_command
    end

    # Removes a specific command from this container.
    # @param name [Symbol] The command to remove.
    def remove_command(name)
      @commands ||= {}
      @commands.delete name
    end

    # Adds all commands from another container into this one. Existing commands will be overwritten.
    # @param container [Module] A module that `extend`s {CommandContainer} from which the commands will be added.
    def include_commands(container)
      handlers = container.instance_variable_get '@commands'
      return unless handlers

      @commands ||= {}
      @commands.merge! handlers
    end

    # Includes another container into this one.
    # @param container [Module] An EventContainer or CommandContainer that will be included if it can.
    def include!(container)
      container_modules = container.singleton_class.included_modules

      # If the container is an EventContainer and we can include it, then do that
      include_events(container) if container_modules.include?(Discordrb::EventContainer) && respond_to?(:include_events)

      if container_modules.include? Discordrb::Commands::CommandContainer
        include_commands(container)
        include_buckets(container)
      elsif !container_modules.include? Discordrb::EventContainer
        raise "Could not include! this particular container - ancestors: #{container_modules}"
      end
    end
  end
end
