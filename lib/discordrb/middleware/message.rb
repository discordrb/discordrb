module Discordrb::Middleware
  # Internal middleware for matching on {Events::MessageEvent} attributes
  # @!visibility private
  class MessageFilter
    def initialize(value, attribute)
      if value.is_a?(Discordrb::Events::Negated)
        @value = value.object
        @negated = true
      else
        @value = value
      end

      @attribute = attribute
    end

    def content_equal(event)
      @value == event.content
    end

    def content_start(event)
      event.content.start_with?(@value)
    end

    def content_start_regexp(event)
      (event.content =~ @value) && (event.content =~ @value).zero?
    end

    def content_end(event)
      event.content.end_with?(@value)
    end

    def content_end_regexp(event)
      # BUG: Doesn't work without a group
      content = event.content
      @value.match(content) ? content.end_with?(@value.match(content)[-1]) : false
    end

    def content_include(event)
      event.content.include?(@value)
    end

    def content_include_regexp(event)
      @value =~ event.content
    end

    def channel_name(event)
      @value == event.channel.name
    end

    def channel_id(event)
      @value == event.channel.id
    end

    def author_name(event)
      @value == event.author.name
    end

    def author_id(event)
      @value == event.author.id
    end

    def author_current_bot(event)
      event.author.current_bot?
    end

    def time_after(event)
      event.timestamp > @value
    end

    def time_before(event)
      event.timestamp < @value
    end

    def private_channel(event)
      !event.channel.private? == !@value
    end

    def call(event, _state)
      matches = send(@attribute, event)
      matches = !matches if @negated
      yield if matches
    end
  end

  Stock.register(:message, :content) do |value|
    MessageFilter.new(value, :content_equal)
  end

  Stock.register(:message, :in) do |value|
    if value.is_a?(String)
      value.delete!('#')
      MessageFilter.new(value, :channel_name)
    elsif value.is_a?(Integer)
      MessageFilter.new(value, :channel_id)
    end
  end

  Stock.register(:message, :start_with) do |value|
    if value.is_a?(String)
      MessageFilter.new(value, :content_start)
    elsif value.is_a?(Regexp)
      MessageFilter.new(value, :content_start_regexp)
    end
  end

  Stock.register(:message, :end_with) do |value|
    if value.is_a?(String)
      MessageFilter.new(value, :content_end)
    elsif value.is_a?(Regexp)
      MessageFilter.new(value, :content_end_regexp)
    end
  end

  Stock.register(:message, :contains) do |value|
    if value.is_a?(String)
      MessageFilter.new(value, :content_include)
    elsif value.is_a?(Regexp)
      MessageFilter.new(value, :content_include_regexp)
    end
  end

  Stock.register(:message, :from) do |value|
    if value.is_a?(String)
      MessageFilter.new(value, :author_name)
    elsif value.is_a?(Integer)
      MessageFilter.new(value, :author_id)
    elsif value == :bot
      MessageFilter.new(value, :author_current_bot)
    end
  end

  Stock.register(:message, :after) do |value|
    MessageFilter.new(value, :time_after)
  end

  Stock.register(:message, :before) do |value|
    MessageFilter.new(value, :time_before)
  end

  Stock.register(:message, :private) do |value|
    MessageFilter.new(value, :private_channel)
  end
end
