module Discordrb
  # The format log timestamps should be in, in strftime format
  LOG_TIMESTAMP_FORMAT = '%Y-%m-%d %H:%M:%S.%L'.freeze

  # Logs debug messages
  class Logger
    # @return [true, false] whether this logger is in extra-fancy mode!
    attr_writer :fancy

    def initialize(fancy = false)
      @fancy = fancy
      self.mode = :normal
    end

    # The modes this logger can have. This is probably useless unless you want to write your own Logger
    MODES = {
      debug: { long: 'DEBUG', short: 'D', format_code: '' },
      good: { long: 'GOOD', short: '✓', format_code: "\u001B[32m" }, # green
      info: { long: 'INFO', short: 'i', format_code: '' },
      warn: { long: 'WARN', short: '!', format_code: "\u001B[33m" }, # yellow
      error: { long: 'ERROR', short: '✗', format_code: "\u001B[31m" }, # red
      out: { long: 'OUT', short: '→', format_code: "\u001B[36m" }, # cyan
      in: { long: 'IN', short: '←', format_code: "\u001B[35m" } # purple
    }.freeze

    # The ANSI format code that resets formatting
    FORMAT_RESET = "\u001B[0m".freeze

    # The ANSI format code that makes something bold
    FORMAT_BOLD = "\u001B[1m".freeze

    MODES.each do |mode, hash|
      define_method(mode) do |message|
        write(message, hash) if @enabled_modes.include? mode
      end
    end

    # Sets the logging mode to :debug
    # @param value [true, false] Whether debug mode should be on. If it is off the mode will be set to :normal.
    def debug=(value)
      self.mode = value ? :debug : :normal
    end

    # Sets the logging mode
    # Possible modes are:
    #  * :debug logs everything
    #  * :verbose logs everything except for debug messages
    #  * :normal logs useful information, warnings and errors
    #  * :quiet only logs warnings and errors
    #  * :silent logs nothing
    # @param value [Symbol] What logging mode to use
    def mode=(value)
      case value
      when :debug
        @enabled_modes = [:debug, :good, :info, :warn, :error, :out, :in]
      when :verbose
        @enabled_modes = [:good, :info, :warn, :error, :out, :in]
      when :normal
        @enabled_modes = [:info, :warn, :error]
      when :quiet
        @enabled_modes = [:warn, :error]
      when :silent
        @enabled_modes = []
      end
    end

    # Logs an exception to the console.
    # @param e [Exception] The exception to log.
    def log_exception(e)
      error("Exception: #{e.inspect}")
      e.backtrace.each { |line| error(line) }
    end

    private

    def write(message, mode)
      thread_name = Thread.current[:discordrb_name]
      timestamp = Time.now.strftime(LOG_TIMESTAMP_FORMAT)
      if @fancy
        fancy_write(message, mode, thread_name, timestamp)
      else
        simple_write(message, mode, thread_name, timestamp)
      end
    end

    def fancy_write(message, mode, thread_name, timestamp)
      puts "#{timestamp} #{FORMAT_BOLD}#{thread_name.ljust(16)}#{FORMAT_RESET} #{mode[:format_code]}#{mode[:short]}#{FORMAT_RESET} #{message}"
    end

    def simple_write(message, mode, thread_name, timestamp)
      puts "[#{mode[:long]} : #{thread_name} @ #{timestamp}] #{message}"
    end
  end
end
