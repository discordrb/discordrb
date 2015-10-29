module Discordrb::Commands
  class Command
    attr_reader :attributes, :name
    
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

  class CommandChain
    def initialize(chain, bot)
      @attributes = bot.attributes
      @chain = chain
      @bot = bot
    end

    def execute_bare(event)
      b_start, b_level = -1, 0
      result = ''
      quoted = false
      hacky_delim, hacky_space, hacky_prev = [0xe001, 0xe002, 0xe003].pack('U*').chars

      @chain.each_char.each_with_index do |char, index|
        # Quote begin
        if char == @attributes[:quote_start] && !quoted
          quoted = true
          next
        end

        # Quote end
        if char == @attributes[:quote_end] && quoted
          quoted = false
          next
        end

        if char == @attributes[:chain_delimiter] && quoted
          result += hacky_delim
          next
        end

        if char == @attributes[:previous] && quoted
          result += hacky_prev
          next
        end

        if char == ' ' && quoted
          result += hacky_space
          next
        end

        if char == @attributes[:sub_chain_start] && !quoted
          b_start = index if b_level == 0
          b_level += 1
        end

        result << char if b_level <= 0

        if char == @attributes[:sub_chain_end] && !quoted
          b_level -= 1
          if b_level == 0
            nested = @chain[b_start + 1 .. index - 1]
            subchain = CommandChain.new(nested, @bot)
            result << subchain.execute(event)
          end
        end
      end

      event.respond("Your subchains are mismatched! Make sure you don't have any extra #{@attributes[:sub_chain_start]}'s or #{@attributes[:sub_chain_end]}'s") unless b_level == 0

      @chain = result

      @chain_args, @chain = divide_chain(@chain)

      prev = ''

      chain_to_split = @chain

      # Don't break if a command is called the same thing as the chain delimiter
      chain_to_split.slice!(1..-1) if chain_to_split.start_with?(@attributes[:chain_delimiter])

      first = true
      chain_to_split.split(@attributes[:chain_delimiter]).each do |command|
        command = @attributes[:chain_delimiter] + command if first && @chain.start_with?(@attributes[:chain_delimiter])
        first = false

        command.strip!

        # Replace the hacky delimiter that was used inside quotes with actual delimiters
        command.gsub! hacky_delim, @attributes[:chain_delimiter]

        first_space = command.index ' '
        command_name = first_space ? command[0..first_space-1] : command
        arguments = first_space ? command[first_space+1..-1] : ''

        # Append a previous sign if none is present
        arguments << @attributes[:previous] unless arguments.include? @attributes[:previous]
        arguments.gsub! @attributes[:previous], prev

        # Replace hacky previous signs with actual ones
        arguments.gsub! hacky_prev, @attributes[:previous]

        arguments = arguments.split ' '

        # Replace the hacky spaces with actual spaces
        arguments.map! do |elem|
          elem.gsub hacky_space, ' '
        end

        # Finally execute the command
        prev = @bot.execute_command(command_name.to_sym, event, arguments)
      end

      prev
    end

    def execute(event)
      old_chain = @chain
      @bot.debug "Executing bare chain"
      result = execute_bare(event)

      @chain_args ||= []

      @bot.debug "Found chain args #{@chain_args}, preliminary result #{result}"

      @chain_args.each do |arg|
        case arg.first
        when 'repeat'
          new_result = ''
          executed_chain = divide_chain(old_chain).last

          arg[1].to_i.times do
            new_result << CommandChain.new(executed_chain, @bot).execute(event)
          end

          result = new_result
        # TODO: more chain arguments
        end
      end

      result
    end

    private

    def divide_chain(chain)
      chain_args_index = chain.index @attributes[:chain_args_delim]
      chain_args = []

      if chain_args_index
        chain_args = chain[0..chain_args_index].split ','

        # Split up the arguments

        chain_args.map! do |arg|
          arg.split ' '
        end

        chain = chain[chain_args_index+1..-1]
      end

      [chain_args, chain]
    end
  end
end
