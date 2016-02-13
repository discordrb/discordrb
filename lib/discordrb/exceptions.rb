module Discordrb
  # Raised when authentication data is invalid or incorrect.
  class InvalidAuthenticationException < RuntimeError; end

  # Raised when a HTTP status code indicates a failure
  class HTTPStatusException < RuntimeError
    attr_reader :status
    def initialize(status)
      @status = status
    end
  end

  # Raised when a message is over the character limit
  class MessageTooLong < RuntimeError; end
end
