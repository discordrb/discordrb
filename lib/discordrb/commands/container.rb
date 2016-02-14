require 'discordrb/container'
require 'discordrb/commands/rate_limiter'

module Discordrb::Commands
  # This module holds a collection of commands that can be easily added to by calling the {CommandContainer#command}
  # function. Other containers can be included into it as well. This allows for modularization of command bots.
  module CommandContainer
    include RateLimiter

    # Adds a new command to the container.
    # @param name [Symbol] The name of the command to add.
    # @param attributes [Hash] The attributes to initialize the command with.
    # @option attributes [Integer] :permission_level The minimum permission level that can use this command, inclusive.
    #   See {CommandBot#set_user_permission} and {CommandBot#set_role_permission}.
    # @option attributes [true, false] :chain_usable Whether this command is able to be used inside of a command chain
    #   or sub-chain. Typically used for administrative commands that shouldn't be done carelessly.
    # @option attributes [true, false] :help_available Whether this command is visible in the help command. See the
    #   :help_command attribute of {CommandBot#initialize}.
    # @option attributes [String] :description A short description of what this command does. Will be shown in the help
    #   command if the user asks for it.
    # @option attributes [String] :usage A short description of how this command should be used. Will be displayed in
    #   the help command or if the user uses it wrong.
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
        new_command = Command.new(name[0], attributes, &block)
        name.each { |n| @commands[n] = new_command }
        new_command
      else
        @commands[name] = Command.new(name, attributes, &block)
      end
    end

    def remove_command(name)
      @commands ||= {}
      @commands.delete name
    end

    # Adds all commands from another container into this one. Existing commands will be overwritten.
    # @param container [Module] A module that `extend`s {CommandContainer} from which the commands will be added.
    def include_commands(container)
      handlers = container.instance_variable_get '@commands'
      @commands ||= {}
      @commands.merge! handlers
    end

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
        fail "Could not include! this particular container - ancestors: #{container_modules}"
      end
    end
  end
end
