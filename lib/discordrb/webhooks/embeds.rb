module Discordrb::Webhooks
  # An embed is a multipart-style attachment to a webhook message that can have a variety of different purposes and
  # appearances.
  class Embed
    def initialize(title: nil, description: nil, url: nil, timestamp: nil, colour: nil, color: nil, footer: nil,
                   image: nil, thumbnail: nil, video: nil, provider: nil, author: nil, fields: [])
      self.title = title
      self.description = description
      @url = url
      @timestamp = timestamp
      self.colour = colour || color
      @footer = footer
      @image = image
      @thumbnail = thumbnail
      @video = video
      @provider = provider
      @author = author
      self.fields = fields
    end

    # see https://discordapp.com/developers/docs/resources/channel#embed-limits
    TITLE_LIMIT = 256
    DESCRIPTION_LIMIT = 2048
    FIELDS_LIMIT = 25
    STRUCTURE_ALL_CHARACTERS_LIMIT = 6000

    # @return [String, nil] title of the embed that will be displayed above everything else.
    attr_reader :title

    # @param title [String, nil] title of the embed that will be displayed above everything else. title length must inside of 256 characters.
    def title=(title)
      raise ArgumentError, 'Title length must inside of 256 characters.' if title && title.length > TITLE_LIMIT
      @title = title
    end

    # @return [String, nil] description for this embed.
    attr_reader :description

    # @param description [String, nil] description for this embed. description length must inside of 2048 characters.
    def description=(description)
      raise ArgumentError, 'Description length must inside of 2048 characters.' if description && description.length > DESCRIPTION_LIMIT
      @description = description
    end

    # @return [String, nil] URL the title should point to
    attr_accessor :url

    # @return [Time, nil] timestamp for this embed. Will be displayed just below the title.
    attr_accessor :timestamp

    # @return [Integer, nil] the colour of the bar to the side, in decimal form
    attr_reader :colour
    alias_method :color, :colour

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

    alias_method :color=, :colour=

    # @example Add a footer to an embed
    #   embed.footer = Discordrb::Webhooks::EmbedFooter.new(text: 'Hello', icon_url: 'https://i.imgur.com/j69wMDu.jpg')
    # @return [EmbedFooter, nil] footer for this embed
    attr_accessor :footer

    # @see EmbedImage
    # @example Add a image to an embed
    #   embed.image = Discordrb::Webhooks::EmbedImage.new(url: 'https://i.imgur.com/PcMltU7.jpg')
    # @return [EmbedImage, nil] image for this embed
    attr_accessor :image

    # @see EmbedThumbnail
    # @example Add a thumbnail to an embed
    #   embed.thumbnail = Discordrb::Webhooks::EmbedThumbnail.new(url: 'https://i.imgur.com/xTG3a1I.jpg')
    # @return [EmbedThumbnail, nil] thumbnail for this embed
    attr_accessor :thumbnail

    # @see EmbedAuthor
    # @example Add a author to an embed
    #   embed.author = Discordrb::Webhooks::EmbedAuthor.new(name: 'meew0', url: 'https://github.com/meew0', icon_url: 'https://avatars2.githubusercontent.com/u/3662915?v=3&s=466')
    # @return [EmbedAuthor, nil] author for this embed
    attr_accessor :author

    # Add a field object to this embed.
    # @param field [EmbedField] The field to add.
    def <<(field)
      self.fields = @fields << field
    end

    # Convenience method to add a field to the embed without having to create one manually.
    # @see EmbedField
    # @example Add a field to an embed, conveniently
    #   embed.add_field(name: 'A field', value: "The field's content")
    # @param name [String] The field's name
    # @param value [String] The field's value
    # @param inline [true, false] Whether the field should be inlined
    def add_field(name: nil, value: nil, inline: nil)
      self << EmbedField.new(name: name, value: value, inline: inline)
    end

    # @return [Array<EmbedField>] the fields attached to this embed.
    attr_reader :fields

    # @param [Array<EmbedField>] the fields attached to this embed. number of fields must inside of 25
    def fields=(fields)
      raise ArgumentError, 'Number of fields must inside of 25' if fields && fields.length > FIELDS_LIMIT
      @fields = fields
    end

    # @return [Hash] a hash representation of this embed, to be converted to JSON.
    def to_hash
      check_all_characters_length
      {
        title: @title,
        description: @description,
        url: @url,
        timestamp: @timestamp && @timestamp.utc.iso8601,
        color: @colour,
        footer: @footer && @footer.to_hash,
        image: @image && @image.to_hash,
        thumbnail: @thumbnail && @thumbnail.to_hash,
        video: @video && @video.to_hash,
        provider: @provider && @provider.to_hash,
        author: @author && @author.to_hash,
        fields: @fields.map(&:to_hash)
      }
    end

    # see https://discordapp.com/developers/docs/resources/channel#embed-limits
    private def check_all_characters_length
      if (
           (@title ? @title.length : 0) +
           (@description ? @description.length : 0) +
           (@url ? @url.length : 0) +
           (@footer && @footer.text ? @footer.text.length : 0) +
           (@author && @author.name ? @author.text.length : 0) +
           (@fields.map { |f| f.name.length + f.value.length }.inject(:+) || 0)
      ) > STRUCTURE_ALL_CHARACTERS_LIMIT
        raise ArgumentError, 'structure all characters must inside 6000 characters.'
      end
    end
  end

  # An embed's footer will be displayed at the very bottom of an embed, together with the timestamp. An icon URL can be
  # set together with some text to be displayed.
  class EmbedFooter
    # see https://discordapp.com/developers/docs/resources/channel#embed-limits
    TEXT_LIMIT = 2048

    # @return [String, nil] text to be displayed in the footer.
    attr_reader :text

    # @param [String, nil] text to be displayed in the footer. text length must inside of 2048 characters.
    def text=(text)
      raise ArgumentError, 'Text length must inside of 2048 characters.' if text && text.length > TEXT_LIMIT
      @text = text
    end

    # @return [String, nil] URL to an icon to be showed alongside the text
    attr_accessor :icon_url

    # Creates a new footer object.
    # @param text [String, nil] The text to be displayed in the footer.
    # @param icon_url [String, nil] The URL to an icon to be showed alongside the text.
    def initialize(text: nil, icon_url: nil)
      self.text = text
      @icon_url = icon_url
    end

    # @return [Hash] a hash representation of this embed footer, to be converted to JSON.
    def to_hash
      {
        text: @text,
        icon_url: @icon_url
      }
    end
  end

  # An embed's image will be displayed at the bottom, in large format. It will replace a footer icon URL if one is set.
  class EmbedImage
    # @return [String, nil] URL of the image
    attr_accessor :url

    # Creates a new image object.
    # @param url [String, nil] The URL of the image.
    def initialize(url: nil)
      @url = url
    end

    # @return [Hash] a hash representation of this embed image, to be converted to JSON.
    def to_hash
      {
        url: @url
      }
    end
  end

  # An embed's thumbnail will be displayed at the right of the message, next to the description and fields. When clicked
  # it will point to the embed URL.
  class EmbedThumbnail
    # @return [String, nil] URL of the thumbnail
    attr_accessor :url

    # Creates a new thumbnail object.
    # @param url [String, nil] The URL of the thumbnail.
    def initialize(url: nil)
      @url = url
    end

    # @return [Hash] a hash representation of this embed thumbnail, to be converted to JSON.
    def to_hash
      {
        url: @url
      }
    end
  end

  # An embed's author will be shown at the top to indicate who "authored" the particular event the webhook was sent for.
  class EmbedAuthor
    # see https://discordapp.com/developers/docs/resources/channel#embed-limits
    NAME_LIMIT = 256

    # @return [String, nil] name of the author.
    attr_reader :name

    # @param [String, nil] name of the author. name length must inside of 256 characters.
    def name=(name)
      raise ArgumentError, 'Name length must inside of 256 characters.' if name && name.length > NAME_LIMIT
      @name = name
    end

    # @return [String, nil] URL the name should link to
    attr_accessor :url

    # @return [String, nil] URL of the icon to be displayed next to the author
    attr_accessor :icon_url

    # Creates a new author object.
    # @param name [String, nil] The name of the author.
    # @param url [String, nil] The URL the name should link to.
    # @param icon_url [String, nil] The URL of the icon to be displayed next to the author.
    def initialize(name: nil, url: nil, icon_url: nil)
      self.name = name
      @url = url
      @icon_url = icon_url
    end

    # @return [Hash] a hash representation of this embed author, to be converted to JSON.
    def to_hash
      {
        name: @name,
        url: @url,
        icon_url: @icon_url
      }
    end
  end

  # A field is a small block of text with a header that can be relatively freely layouted with other fields.
  class EmbedField
    # see https://discordapp.com/developers/docs/resources/channel#embed-limits
    NAME_LIMIT = 256
    VALUE_LIMIT = 1024

    # @return [String, nil] name of the field, displayed in bold at the top of the field.
    attr_reader :name

    # @param name [String] name of the field, displayed in bold at the top of the field. name length must inside 256 characters and not empty.
    def name=(name)
      raise ArgumentError, 'Name length must inside of 256 characters.' if name.length > NAME_LIMIT
      raise ArgumentError, 'Name must not empty.' if name.empty?
      @name = name
    end

    # @return [String, nil] value of the field, displayed in normal text below the name.
    attr_reader :value

    # @param value [String] value of the field, displayed in normal text below the name.
    def value=(value)
      raise ArgumentError, 'Value length must inside of 1024 characters.' if value.length > VALUE_LIMIT
      raise ArgumentError, 'Value must not empty.' if value.empty?
      @value = value
    end

    # @return [true, false] whether the field should be displayed inline with other fields.
    attr_accessor :inline

    # Creates a new field object.
    # @param name [String, nil] The name of the field, displayed in bold at the top of the field.
    # @param value [String, nil] The value of the field, displayed in normal text below the name.
    # @param inline [true, false] Whether the field should be displayed inline with other fields.
    def initialize(name: nil, value: nil, inline: false)
      name && self.name = name
      value && self.value = value
      @inline = inline
    end

    # TODO : nil check name and value
    # @return [Hash] a hash representation of this embed field, to be converted to JSON.
    def to_hash
      {
        name: @name,
        value: @value,
        inline: @inline
      }
    end
  end
end
