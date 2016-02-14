module Discordrb::Commands
  class Bucket
    # Makes a new bucket
    # @param limit [Integer, nil] How many requests the user may perform in the given time_span, or nil if there should be no limit.
    # @param time_span [Integer, nil] The time span after which the request count is reset, in seconds, or nil if the bucket should never be reset. (If this is nil, limit should be nil too)
    # @param delay [Integer, nil] The delay for which the user has to wait after performing a request, in seconds, or nil if the user shouldn't have to wait.
    def initialize(limit, time_span, delay)
      fail ArgumentError, '`limit` and `time_span` have to either both be set or both be nil!' if !limit != !time_span

      @limit = limit
      @time_span = time_span
      @delay = delay

      @bucket = {}
    end

    # Performs a rate limiting request
    # @param thing [#resolve_id, Integer, Symbol] The particular thing that should be rate-limited (usually a user/channel, but you can also choose arbitrary integers or symbols)
    # @return [Integer, false] the waiting time until the next request, or false if the request succeeded
    def rate_limited?(thing)

    end

    private

    def resolve_key(thing)
      return thing.resolve_id if thing.respond_to? :resolve_id
      return thing if thing.is_a?(Integer) || thing.is_a?(Symbol)
      fail ArgumentError, "Cannot use a #{thing.class} as a rate limiting key!"
    end
  end

  class RateLimiter
    def initialize

    end
  end
end
