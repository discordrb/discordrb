module Discordrb::Commands
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