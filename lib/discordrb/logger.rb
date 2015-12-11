module Discordrb
  # Logs debug messages
  class Logger
    def debug(message, important = false)
      puts "[DEBUG : #{Thread.current[:discordrb_name]} @ #{Time.now}] #{message}" if @debug || important
    end

    def log_exception(e)
      debug("Exception: #{e.inspect}", true)
      e.backtrace.each { |line| debug(line, true) }
    end
  end
end
