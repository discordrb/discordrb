# frozen_string_literal: true

require 'discordrb/container'
require 'discordrb/commands/rate_limiter'

module Discordrb::Commands
  # This module holds a collection of commands that can be easily added to by calling the {CommandContainer#command}
  # function. Other containers can be included into it as well. This allows for modularization of command bots.
  module CommandContainer
    include RateLimiter

    # @return [Hash<Symbol, Command>] hash of command names and commands this container has.
    attr_reader :commands

    # Adds a new command to the container.
    # @param name [Symbol, Array<Symbol>] The name of the command to add, or an array of multiple names for the command
    # @param attributes [Hash] The attributes to initialize the command with.
    # @option attributes [Integer] :permission_level The minimum permission level that can use this command, inclusive.
    #   See {CommandBot#set_user_permission} and {CommandBot#set_role_permission}.
    # @option attributes [String, false] :permission_message Message to display when a user does not have sufficient
    #   permissions to execute a command. %name% in the message will be replaced with the name of the command. Disable
    #   the message by setting this option to false.
    # @option attributes [Array<Symbol>] :required_permissions Discord action permissions (e.g. `:kick_members`) that
    #   should be required to use this command. See {Discordrb::Permissions::Flags} for a list.
    # @option attributes [Array<Role>, Array<#resolve_id>] :required_roles Roles that user should have to use this command.
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
    # @yield The block is executed when the command is executed.
    # @yieldparam event [CommandEvent] The event of the message that contained the command.
    # @return [Command] The command that was added.
    def command(name, attributes = {}, &block)
      @commands ||= {}
      if name.is_a? Array
        new_command = nil

        name.each do |e|
          new_command = Command.new(e, attributes, &block)
          @commands[e] = new_command
        end

        new_command
      else
        @commands[name] = Command.new(name, attributes, &block)
      end
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
      if container_modules.include?(Discordrb::EventContainer) && respond_to?(:include_events)
        include_events(container)
      end

      if container_modules.include? Discordrb::Commands::CommandContainer
        include_commands(container)
        include_buckets(container)
      elsif !container_modules.include? Discordrb::EventContainer
        raise "Could not include! this particular container - ancestors: #{container_modules}"
      end
    end
  end
end
