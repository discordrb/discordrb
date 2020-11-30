# frozen_string_literal: true

module Discordrb::Commands
  # Command that can be called in a chain
  class Command
    # @return [Hash] the attributes the command was initialized with
    attr_reader :attributes

    # @return [Symbol] the name of this command
    attr_reader :name

    # @!visibility private
    def initialize(name, attributes = {}, &block)
      @name = name
      @attributes = {
        # The lowest permission level that can use the command
        permission_level: attributes[:permission_level] || 0,

        # Message to display when a user does not have sufficient permissions to execute a command
        permission_message: attributes[:permission_message].is_a?(FalseClass) ? nil : (attributes[:permission_message] || "You don't have permission to execute command %name%!"),

        # Discord action permissions required to use this command
        required_permissions: attributes[:required_permissions] || [],

        # Roles required to use this command (all? comparison)
        required_roles: attributes[:required_roles] || [],

        # Roles allowed to use this command (any? comparison)
        allowed_roles: attributes[:allowed_roles] || [],

        # Channels this command can be used on
        channels: attributes[:channels] || nil,

        # Whether this command is usable in a command chain
        chain_usable: attributes[:chain_usable].nil? ? true : attributes[:chain_usable],

        # Whether this command should show up in the help command
        help_available: attributes[:help_available].nil? ? true : attributes[:help_available],

        # Description (for help command)
        description: attributes[:description] || nil,

        # Usage description (for help command and error messages)
        usage: attributes[:usage] || nil,

        # Array of arguments (for type-checking)
        arg_types: attributes[:arg_types] || nil,

        # Parameter list (for help command and error messages)
        parameters: attributes[:parameters] || nil,

        # Minimum number of arguments
        min_args: attributes[:min_args] || 0,

        # Maximum number of arguments (-1 for no limit)
        max_args: attributes[:max_args] || -1,

        # Message to display upon rate limiting (%time% in the message for the remaining time until the next possible
        # request, nil for no message)
        rate_limit_message: attributes[:rate_limit_message],

        # Rate limiting bucket (nil for no rate limiting)
        bucket: attributes[:bucket],

        # Block for handling internal exceptions, or a string to respond with
        rescue: attributes[:rescue],

        # A list of aliases that reference this command
        aliases: attributes[:aliases] || []
      }

      @block = block
    end

    # Calls this command and executes the code inside.
    # @param event [CommandEvent] The event to call the command with.
    # @param arguments [Array<String>] The attributes for the command.
    # @param chained [true, false] Whether or not this command is part of a command chain.
    # @param check_permissions [true, false] Whether the user's permission to execute the command (i.e. rate limits)
    #   should be checked.
    # @return [String] the result of the execution.
    def call(event, arguments, chained = false, check_permissions = true)
      if arguments.length < @attributes[:min_args]
        response = "Too few arguments for command `#{name}`!"
        response += "\nUsage: `#{@attributes[:usage]}`" if @attributes[:usage]
        event.respond(response)
        return
      end
      if @attributes[:max_args] >= 0 && arguments.length > @attributes[:max_args]
        response = "Too many arguments for command `#{name}`!"
        response += "\nUsage: `#{@attributes[:usage]}`" if @attributes[:usage]
        event.respond(response)
        return
      end
      unless @attributes[:chain_usable] && !chained
        event.respond "Command `#{name}` cannot be used in a command chain!"
        return
      end

      if check_permissions
        rate_limited = event.bot.rate_limited?(@attributes[:bucket], event.author)
        if @attributes[:bucket] && rate_limited
          event.respond @attributes[:rate_limit_message].gsub('%time%', rate_limited.round(2).to_s) if @attributes[:rate_limit_message]
          return
        end
      end

      result = @block.call(event, *arguments)
      event.drain_into(result)
    rescue LocalJumpError => e # occurs when breaking
      result = e.exit_value
      event.drain_into(result)
    rescue StandardError => e # Something went wrong inside our @block!
      rescue_value = @attributes[:rescue] || event.bot.attributes[:rescue]
      if rescue_value
        event.respond(rescue_value.gsub('%exception%', e.message)) if rescue_value.is_a?(String)
        rescue_value.call(event, e) if rescue_value.respond_to?(:call)
      end

      raise e
    end
  end

  # A command that references another command
  class CommandAlias
    # @return [Symbol] the name of this alias
    attr_reader :name

    # @return [Command] the command this alias points to
    attr_reader :aliased_command

    def initialize(name, aliased_command)
      @name = name
      @aliased_command = aliased_command
    end
  end

  # Command chain, may have multiple commands, nested and commands
  class CommandChain
    # @param chain [String] The string the chain should be parsed from.
    # @param bot [CommandBot] The bot that executes this command chain.
    # @param subchain [true, false] Whether this chain is a sub chain of another chain.
    def initialize(chain, bot, subchain = false)
      @attributes = bot.attributes
      @chain = chain
      @bot = bot
      @subchain = subchain
    end

    # Parses the command chain itself, including sub-chains, and executes it. Executes only the command chain, without
    # its chain arguments.
    # @param event [CommandEvent] The event to execute the chain with.
    # @return [String] the result of the execution.
    def execute_bare(event)
      b_start = -1
      b_level = 0
      result = ''
      quoted = false
      escaped = false
      hacky_delim, hacky_space, hacky_prev, hacky_newline = [0xe001, 0xe002, 0xe003, 0xe004].pack('U*').chars

      @chain.each_char.each_with_index do |char, index|
        # Escape character
        if char == '\\' && !escaped
          escaped = true
          next
        elsif escaped && b_level <= 0
          result += char
          escaped = false
          next
        end

        if quoted
          # Quote end
          if char == @attributes[:quote_end]
            quoted = false
            next
          end

          if b_level <= 0
            case char
            when @attributes[:chain_delimiter]
              result += hacky_delim
              next
            when @attributes[:previous]
              result += hacky_prev
              next
            when ' '
              result += hacky_space
              next
            when "\n"
              result += hacky_newline
              next
            end
          end
        else
          case char
          when @attributes[:quote_start] # Quote begin
            quoted = true
            next
          when @attributes[:sub_chain_start]
            b_start = index if b_level.zero?
            b_level += 1
          end
        end

        result += char if b_level <= 0

        next unless char == @attributes[:sub_chain_end] && !quoted

        b_level -= 1
        next unless b_level.zero?

        nested = @chain[b_start + 1..index - 1]
        subchain = CommandChain.new(nested, @bot, true)
        result += subchain.execute(event)
      end

      event.respond("Your subchains are mismatched! Make sure you don't have any extra #{@attributes[:sub_chain_start]}'s or #{@attributes[:sub_chain_end]}'s") unless b_level.zero?

      @chain = result

      @chain_args, @chain = divide_chain(@chain)

      prev = ''

      chain_to_split = @chain

      # Don't break if a command is called the same thing as the chain delimiter
      chain_to_split = chain_to_split.slice(1..-1) if !@attributes[:chain_delimiter].empty? && chain_to_split.start_with?(@attributes[:chain_delimiter])

      first = true
      split_chain = if @attributes[:chain_delimiter].empty?
                      [chain_to_split]
                    else
                      chain_to_split.split(@attributes[:chain_delimiter])
                    end
      split_chain.each do |command|
        command = @attributes[:chain_delimiter] + command if first && @chain.start_with?(@attributes[:chain_delimiter])
        first = false

        command = command.strip

        # Replace the hacky delimiter that was used inside quotes with actual delimiters
        command = command.gsub hacky_delim, @attributes[:chain_delimiter]

        first_space = command.index ' '
        command_name = first_space ? command[0..first_space - 1] : command
        arguments = first_space ? command[first_space + 1..-1] : ''

        # Append a previous sign if none is present
        arguments += @attributes[:previous] unless arguments.include? @attributes[:previous]
        arguments = arguments.gsub @attributes[:previous], prev

        # Replace hacky previous signs with actual ones
        arguments = arguments.gsub hacky_prev, @attributes[:previous]

        arguments = arguments.split ' '

        # Replace the hacky spaces/newlines with actual ones
        arguments.map! do |elem|
          elem.gsub(hacky_space, ' ').gsub(hacky_newline, "\n")
        end

        # Finally execute the command
        prev = @bot.execute_command(command_name.to_sym, event, arguments, split_chain.length > 1 || @subchain)

        # Stop chain if execute_command failed (maybe the command doesn't exist, or permissions failed, etc.)
        break unless prev
      end

      prev
    end

    # Divides the command chain into chain arguments and command chain, then executes them both.
    # @param event [CommandEvent] The event to execute the command with.
    # @return [String] the result of the command chain execution.
    def execute(event)
      old_chain = @chain
      @bot.debug 'Executing bare chain'
      result = execute_bare(event)

      @chain_args ||= []

      @bot.debug "Found chain args #{@chain_args}, preliminary result #{result}"

      @chain_args.each do |arg|
        case arg.first
        when 'repeat'
          new_result = ''
          executed_chain = divide_chain(old_chain).last

          arg[1].to_i.times do
            chain_result = CommandChain.new(executed_chain, @bot).execute(event)
            new_result += chain_result if chain_result
          end

          result = new_result
          # TODO: more chain arguments
        end
      end

      result
    end

    private

    def divide_chain(chain)
      chain_args_index = chain.index(@attributes[:chain_args_delim]) unless @attributes[:chain_args_delim].empty?
      chain_args = []

      if chain_args_index
        chain_args = chain[0..chain_args_index].split ','

        # Split up the arguments

        chain_args.map! do |arg|
          arg.split ' '
        end

        chain = chain[chain_args_index + 1..-1]
      end

      [chain_args, chain]
    end
  end
end
