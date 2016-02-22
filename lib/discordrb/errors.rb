module Discordrb
  # Custom errors raised in various places
  module Errors
    # Raised when authentication data is invalid or incorrect.
    class InvalidAuthenticationError < RuntimeError; end

    # Raised when a HTTP status code indicates a failure
    class HTTPStatusError < RuntimeError
      attr_reader :status
      def initialize(status)
        @status = status
      end
    end

    # Raised when a message is over the character limit
    class MessageTooLong < RuntimeError; end

    # Raised when the bot can't do something because its permissions on the server are insufficient
    class NoPermission < RuntimeError; end

    # Raised when the bot gets a HTTP 502 error, which is usually caused by Cloudflare.
    class CloudflareError < RuntimeError; end
  end
end
