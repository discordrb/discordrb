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

    # Converts this Reaction into a string that can be sent back to Discord in other reaction endpoints.
    # If ID is present, it will be rendered into the form of `name:id`.
    # @return [String] the name of this reaction, including the ID if it is a custom emoji
    def to_s
      emoji.to_reaction
    end
  end
end
