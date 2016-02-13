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
  end
end
