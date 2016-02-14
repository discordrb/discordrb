module Discordrb
  # Logs debug messages
  class Logger
    # @return [true, false] whether or not this logger should be in debug mode (all debug messages will be printed)
    attr_writer :debug

    # @see Bot#debug
    def debug(message, important = false)
      puts "[DEBUG : #{Thread.current[:discordrb_name]} @ #{Time.now}] #{message}" if @debug || important
    end

    # @see Bot#log_exception
    def log_exception(e, important = true)
      debug("Exception: #{e.inspect}", important)
      e.backtrace.each { |line| debug(line, important) }
    end
  end
end
