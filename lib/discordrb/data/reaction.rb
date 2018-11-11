# frozen_string_literal: true

module Discordrb
  # A reaction to a message.
  class Reaction
    # @return [Integer] the amount of users who have reacted with this reaction
    attr_reader :count

    # @return [true, false] whether the current bot or user used this reaction
    attr_reader :me
    alias_method :me?, :me

    # @return [Integer] the ID of the emoji, if it was custom
    attr_reader :id

    # @return [String] the name or unicode representation of the emoji
    attr_reader :name

    def initialize(data)
      @count = data['count']
      @me = data['me']
      @id = data['emoji']['id'].nil? ? nil : data['emoji']['id'].to_i
      @name = data['emoji']['name']
    end

    # Converts this Reaction into a string that can be sent back to Discord in other reaction endpoints.
    # If ID is present, it will be rendered into the form of `name:id`.
    # @return [String] the name of this reaction, including the ID if it is a custom emoji
    def to_s
      id.nil? ? name : "#{name}:#{id}"
    end
  end
end
