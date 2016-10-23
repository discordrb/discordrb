module Discordrb::Webhooks
  # A class that acts as a builder for a webhook message object.
  class Builder
    def initialize(content: '', username: nil, avatar_url: nil, tts: false, file: nil, embeds: [])
      @content = content
      @username = username
      @avatar_url = avatar_url
      @tts = tts
      @file = file
      @embeds = embeds
    end

    # The content of the message. May be 2000 characters long at most.
    # @return [String] the content of the message.
    attr_accessor :content
  end
end
