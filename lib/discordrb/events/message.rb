module Discordrb::Events
  class MessageEvent
    attr_reader :message

    def initialize(message)
      @message = message
    end

    def author; @message.author; end
    alias_method :user, :author
    def channel; @message.channel; end
    def content; @message.content; end
    alias_method :text, :content
  end

  class MessageEventHandler
    def initialize(attributes, &block)
      @attributes = attributes
      @block = block
    end

    def match(event)
    end
  end
end
