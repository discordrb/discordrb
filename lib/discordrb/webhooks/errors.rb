# frozen_string_literal: true

module Discordrb::Webhooks
  # Custom webhook and embed related errors
  module Errors
    # Raised when an Embed doesn't meet certain formatting criteria
    class EmbedFormatError < RuntimeError; end
   
    # Raised when a Client tries to execute a webhook with too many embed objects attached
    class TooManyEmbeds < RuntimeError
      # Default message for this exception
      def message
        'Webhook messages can only contain up to 5 embed objects.'
      end
    end
  end
end
