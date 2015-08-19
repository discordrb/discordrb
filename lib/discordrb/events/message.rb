module Discordrb::Events
  class MessageEvent
    attr_reader :message

    def initialize(message)
      @message = message
    end

    def author; @message.author; end
    def user; @message.author; end
    def channel; @message.channel; end
    def content; @message.content; end
    def text; @message.content; end
  end
end
