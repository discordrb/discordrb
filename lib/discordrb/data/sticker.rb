# frozen_string_literal: true

module Discordrb
  class Sticker
    include IDObject

    FORMAT_TYPE = {
      1 => :png,
      2 => :apng,
      3 => :lottie,
    }.freeze

    attr_reader :pack_id
    attr_reader :name
    attr_reader :description
    attr_reader :tags
    attr_reader :asset
    attr_reader :preview_asset
    attr_reader :format_type

    def initialize(data)
      @id = data['id'].to_i
      @pack_id = data['pack_id'].to_i
      @name = data['name']
      @description = data['description']
      @tags = data['tags']
      @asset = data['asset']
      @preview_asset = data['preview_asset']
      @format_type = parse_format_type(data['format_type'])
    end

    def to_s
      # TODO
    end

    private

    def parse_format_type(type)
      raise ArgumentError, 'Invalid sticker format type specified' unless FORMAT_TYPE.keys.include?(type)

      FORMAT_TYPE[type]
    end
  end
end
