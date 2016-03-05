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

    # Writes a debug message to the console.
    # @param important [true, false] Whether this message should be printed regardless of debug mode being on or off.
    def debug(message, important = false)
      puts "[DEBUG : #{Thread.current[:discordrb_name]} @ #{Time.now.strftime(LOG_TIMESTAMP_FORMAT)}] #{message}" if @debug || important
    end

    # Logs an exception to the console.
    # @param e [Exception] The exception to log.
    # @param important [true, false] Whether this exception should be printed regardless of debug mode being on or off.
    def log_exception(e, important = true)
      debug("Exception: #{e.inspect}", important)
      e.backtrace.each { |line| debug(line, important) }
    end
  end
end
