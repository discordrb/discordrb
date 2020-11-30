# frozen_string_literal: true

module Discordrb
  # Utility class for wrapping paginated endpoints. It is [Enumerable](https://ruby-doc.org/core-2.5.1/Enumerable.html),
  # similar to an `Array`, so most of the same methods can be used to filter the results of the request
  # that it wraps. If you simply want an array of all of the results, `#to_a` can be called.
  class Paginator
    include Enumerable

    # Creates a new {Paginator}
    # @param limit [Integer] the maximum number of items to request before stopping
    # @param direction [:up, :down] the order in which results are returned in
    # @yield [Array, nil] the last page of results, or nil if this is the first iteration.
    #   This should be used to request the next page of results.
    # @yieldreturn [Array] the next page of results
    def initialize(limit, direction, &block)
      @count = 0
      @limit = limit
      @direction = direction
      @block = block
    end

    # Yields every item produced by the wrapped request, until it returns
    # no more results or the configured `limit` is reached.
    def each
      last_page = nil
      until limit_check
        page = @block.call(last_page)
        return if page.empty?

        enumerator = case @direction
                     when :down
                       page.each
                     when :up
                       page.reverse_each
                     end

        enumerator.each do |item|
          yield item
          @count += 1
          break if limit_check
        end

        last_page = page
      end
    end

    private

    # Whether the paginator limit has been exceeded
    def limit_check
      return false if @limit.nil?

      @count >= @limit
    end
  end
end
