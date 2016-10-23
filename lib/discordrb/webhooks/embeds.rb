module Discordrb::Webhooks
  # An embed is a multipart-style attachment to a webhook message that can have a variety of different purposes and
  # appearances.
  class Embed
    def initialize(title: nil, description: nil, url: nil, timestamp: nil, colour: nil, footer: nil, image: nil,
                   thumbnail: nil, video: nil, provider: nil, author: nil, fields: [])
      @title = title
      @description = description
      @url = url
      @timestamp = timestamp
      @colour = colour
      @footer = footer
      @image = image
      @thumbnail = thumbnail
      @video = video
      @provider = provider
      @author = author
      @fields = fields
    end

    # The title of this embed that will be displayed above everything else.
    # @return [String]
    attr_accessor :title

    # The description for this embed.
    # @return [String]
    attr_accessor :description

    # The URL the title should point to.
    # @return [String]
    attr_accessor :url

    # The timestamp for this embed. Will be displayed just below the title.
    # @return [Time]
    attr_accessor :timestamp

    # @return [Integer] the colour of the bar to the side, in decimal form.
    attr_reader :colour

    # Sets the colour of the bar to the side of the embed to something new.
    # @param value [Integer, String, {Integer, Integer, Integer}] The colour in decimal, hexadecimal, or R/G/B decimal
    #   form.
    def colour=(value)
      if value.is_a? Integer
        raise ArgumentError, 'Embed colour must be 24-bit!' if value >= 16_777_216
        @colour = value
      elsif value.is_a? String
        self.colour = value.delete('#').to_i(16)
      elsif value.is_a? Array
        raise ArgumentError, 'Colour tuple must have three values!' if value.length != 3
        self.colour = value[0] << 16 | value[1] << 8 | value[2]
      end
    end
  end

  # An embed's footer will be displayed at the very bottom of an embed, together with the timestamp. An icon URL can be
  # set together with some text to be displayed.
  class EmbedFooter
    # Creates a new footer object.
    # @param text [String, nil] The text to be displayed in the footer.
    # @param icon_url [String, nil] The URL to an icon to be showed alongside the text.
    def initialize(text: nil, icon_url: nil)
      @text = text
      @icon_url = icon_url
    end
  end
end
