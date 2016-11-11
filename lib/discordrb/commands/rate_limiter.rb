# frozen_string_literal: true

module Discordrb::Commands
  # This class represents a bucket for rate limiting - it keeps track of how many requests have been made and when
  # exactly the user should be rate limited.
  class Bucket
    # Makes a new bucket
    # @param limit [Integer, nil] How many requests the user may perform in the given time_span, or nil if there should be no limit.
    # @param time_span [Integer, nil] The time span after which the request count is reset, in seconds, or nil if the bucket should never be reset. (If this is nil, limit should be nil too)
    # @param delay [Integer, nil] The delay for which the user has to wait after performing a request, in seconds, or nil if the user shouldn't have to wait.
    def initialize(limit, time_span, delay)
      raise ArgumentError, '`limit` and `time_span` have to either both be set or both be nil!' if !limit != !time_span

      @limit = limit
      @time_span = time_span
      @delay = delay

      @bucket = {}
    end

    # Cleans the bucket, removing all elements that aren't necessary anymore
    # @param rate_limit_time [Time] The time to base the cleaning on, only useful for testing.
    def clean(rate_limit_time = nil)
      rate_limit_time ||= Time.now

      @bucket.delete_if do |_, limit_hash|
        # Time limit has not run out
        return false if @time_span && rate_limit_time < (limit_hash[:set_time] + @time_span)

        # Delay has not run out
        return false if @delay && rate_limit_time < (limit_hash[:last_time] + @delay)

        true
      end
    end

    # Performs a rate limiting request
    # @param thing [#resolve_id, Integer, Symbol] The particular thing that should be rate-limited (usually a user/channel, but you can also choose arbitrary integers or symbols)
    # @param rate_limit_time [Time] The time to base the rate limiting on, only useful for testing.
    # @return [Integer, false] the waiting time until the next request, in seconds, or false if the request succeeded
    def rate_limited?(thing, rate_limit_time = nil)
      key = resolve_key thing
      limit_hash = @bucket[key]

      # First case: limit_hash doesn't exist yet
      unless limit_hash
        @bucket[key] = {
          last_time: Time.now,
          set_time: Time.now,
          count: 1
        }

        return false
      end

      # Define the time at which we're being rate limited once so it doesn't get inaccurate
      rate_limit_time ||= Time.now

      if @limit && (limit_hash[:count] + 1) > @limit
        # Second case: Count is over the limit and the time has not run out yet
        return (limit_hash[:set_time] + @time_span) - rate_limit_time if @time_span && rate_limit_time < (limit_hash[:set_time] + @time_span)

        # Third case: Count is over the limit but the time has run out
        # Don't return anything here because there may still be delay-based limiting
        limit_hash[:set_time] = rate_limit_time
        limit_hash[:count] = 0
      end

      if @delay && rate_limit_time < (limit_hash[:last_time] + @delay)
        # Fourth case: we're being delayed
        (limit_hash[:last_time] + @delay) - rate_limit_time
      else
        # Fifth case: no rate limiting at all! Increment the count, set the last_time, and return false
        limit_hash[:last_time] = rate_limit_time
        limit_hash[:count] += 1
        false
      end
    end

    private

    def resolve_key(thing)
      return thing.resolve_id if thing.respond_to?(:resolve_id) && !thing.is_a?(String)
      return thing if thing.is_a?(Integer) || thing.is_a?(Symbol)
      raise ArgumentError, "Cannot use a #{thing.class} as a rate limiting key!"
    end
  end

  # Represents a collection of {Bucket}s.
  module RateLimiter
    # Defines a new bucket for this rate limiter.
    # @param key [Symbol] The name for this new bucket.
    # @param attributes [Hash] The attributes to initialize the bucket with.
    # @option attributes [Integer] :limit The limit of requests to perform in the given time span.
    # @option attributes [Integer] :time_span How many seconds until the limit should be reset.
    # @option attributes [Integer] :delay How many seconds the user has to wait after each request.
    # @see Bucket#initialize
    # @return [Bucket] the created bucket.
    def bucket(key, attributes)
      @buckets ||= {}
      @buckets[key] = Bucket.new(attributes[:limit], attributes[:time_span], attributes[:delay])
    end

    # Performs a rate limit request.
    # @param key [Symbol] Which bucket to perform the request for.
    # @param thing [#resolve_id, Integer, Symbol] What should be rate-limited.
    # @see Bucket#rate_limited?
    # @return [Integer, false] How much time to wait or false if the request succeeded.
    def rate_limited?(key, thing)
      # Check whether the bucket actually exists
      return false unless @buckets && @buckets[key]

      @buckets[key].rate_limited?(thing)
    end

    # Cleans all buckets
    # @see Bucket#clean
    def clean
      @buckets.each(&:clean)
    end

    # Adds all the buckets from another RateLimiter onto this one.
    # @param limiter [Module] Another {RateLimiter} module
    def include_buckets(limiter)
      buckets = limiter.instance_variable_get('@buckets') || {}
      @buckets ||= {}
      @buckets.merge! buckets
    end
  end

  # This class provides a convenient way to do rate-limiting on non-command events.
  # @see RateLimiter
  class SimpleRateLimiter
    include RateLimiter

    # Makes a new rate limiter
    def initialize
      @buckets = {}
    end
  end
end
