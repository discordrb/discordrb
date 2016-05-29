# frozen_string_literal: true

module Discordrb
  # Custom errors raised in various places
  module Errors
    # Raised when authentication data is invalid or incorrect.
    class InvalidAuthenticationError < RuntimeError
      # Default message for this exception
      def message
        'User login failed due to an invalid email or password!'
      end
    end

    # Raised when a message is over the character limit
    class MessageTooLong < RuntimeError; end

    # Raised when the bot can't do something because its permissions on the server are insufficient
    class NoPermission < RuntimeError; end

    # Raised when the bot gets a HTTP 502 error, which is usually caused by Cloudflare.
    class CloudflareError < RuntimeError; end

    # Generic class for errors denoted by API error codes
    class CodeError < RuntimeError
      class << self
        # @return [Integer] The error code represented by this error class.
        def code
          return @code if @code

          # This class has no code, so search the superclasses
          class_with_code = ancestors.find { |c| !c.code.nil? }
          return class_with_code.code if class_with_code

          # No superclass has a code for whatever reason
          raise "Tried to get this error's code, but neither it nor any of its ancestors has one!"
        end
      end

      # Create a new error with a particular message (the code should be defined by the class instance variable)
      # @param message [String] the message to use
      def initialize(message)
        @message = message
      end
    end

    # Create a new code error class
    # rubocop:disable Style/MethodName
    def self.Code(code)
      classy = Class.new(CodeError)
      classy.instance_variable_set('@code', code)
      classy
    end
  end
end
