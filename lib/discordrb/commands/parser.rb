class Command
  def initialize(name, attributes = {}, &block)
    @name = name
    @attributes = {
      # The lowest permission level that can use the command
      permission_level: attributes[:permission_level] || 0,

      # Whether this command is usable in a command chain
      chain_usable: attributes[:chain_usable].nil? ? true : attributes[:chain_usable],

      # Description (for help command)
      description: attributes[:description] || '',

      # Usage description (for help command and error messages)
      usage: attributes[:usage] || '',

      # Minimum number of arguments
      min_args: attributes[:min_args] || 0,

      # Maximum number of arguments (-1 for no limit)
      max_args: attributes[:max_args] || -1
    }

    @block = block
  end

  def call(event, arguments)
    @block.call(event, *arguments)
  end
end
