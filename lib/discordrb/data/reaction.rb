# frozen_string_literal: true

module Discordrb
  # A reaction to a message.
  class Reaction
    # @return [Integer] the amount of users who have reacted with this reaction
    attr_reader :count

    # @return [true, false] whether the current bot or user used this reaction
    attr_reader :me
    alias_method :me?, :me

    # @return [Emoji] the emoji that was reacted with
    attr_reader :emoji

    def initialize(data, server = nil)
      @count = data['count']
      @me = data['me']
      @emoji = Emoji.new(data['emoji'], server)
    end
  end
end
