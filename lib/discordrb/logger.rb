module Discordrb
  LOG_TIMESTAMP_FORMAT = '%Y-%m-%d %H:%M:%S.%L %z'.freeze

  # Logs debug messages
  class Logger
    # @return [true, false] whether or not this logger should be in debug mode (all debug messages will be printed)
    attr_writer :debug

    # @return [true, false] whether this logger is in extra-fancy mode!
    attr_writer :fancy

    MODES = {
      debug: { long: 'DEBUG', short: 'D', format_code: '' },
      good: { long: 'GOOD', short: '✓', format_code: "\u001B[32m" }, # green
      info: { long: 'INFO', short: 'i', format_code: '' },
      warn: { long: 'WARN', short: '!', format_code: "\u001B[33m" }, # yellow
      error: { long: 'ERROR', short: '✗', format_code: "\u001B[31m" }, # red
      out: { long: 'OUT', short: '→', format_code: "\u001B[36m" }, # cyan
      in: { long: 'IN', short: '←', format_code: "\u001B[35m" } # purple
    }.freeze

    FORMAT_RESET = "\u001B[0m".freeze
    FORMAT_BOLD = "\u001B[1m".freeze

    MODES.each do |mode, hash|
      define_method(mode) do |message|
        write(message, hash)
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
