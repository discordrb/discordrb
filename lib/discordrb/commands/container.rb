require 'discordrb/container'

module Discordrb::Commands
  # This module holds a collection of commands that can be easily added to by calling the {CommandContainer#command}
  # function. Other containers can be included into it as well. This allows for modularization of command bots.
  module CommandContainer
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
      elsif !container_modules.include? Discordrb::EventContainer
        fail "Could not include! this particular container - ancestors: #{container_modules}"
      end
    end
  end
end
