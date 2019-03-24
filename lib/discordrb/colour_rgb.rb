# frozen_string_literal: true

module Discordrb
  # A colour (red, green and blue values). Used for role colours. If you prefer the American spelling, the alias
  # {ColorRGB} is also available.
  class ColourRGB
    # @return [Integer] the red part of this colour (0-255).
    attr_reader :red

    # @return [Integer] the green part of this colour (0-255).
    attr_reader :green

    # @return [Integer] the blue part of this colour (0-255).
    attr_reader :blue

    # @return [Integer] the colour's RGB values combined into one integer.
    attr_reader :combined
    alias_method :to_i, :combined

    # Make a new colour from the combined value.
    # @param combined [String, Integer] The colour's RGB values combined into one integer or a hexadecimal string
    # @example Initialize a with a base 10 integer
    #   ColourRGB.new(7506394) #=> ColourRGB
    #   ColourRGB.new(0x7289da) #=> ColourRGB
    # @example Initialize a with a hexadecimal string
    #   ColourRGB.new('7289da') #=> ColourRGB
    def initialize(combined)
      @combined = combined.is_a?(String) ? combined.to_i(16) : combined
      @red = (@combined >> 16) & 0xFF
      @green = (@combined >> 8) & 0xFF
      @blue = @combined & 0xFF
    end

    # @return [String] the colour as a hexadecimal.
    def hex
      @combined.to_s(16)
    end
    alias_method :hexadecimal, :hex
  end

  # Alias for the class {ColourRGB}
  ColorRGB = ColourRGB
end
