# frozen_string_literal: true

require 'discordrb/webhooks'

describe Discordrb::Webhooks do
  describe Discordrb::Webhooks::Builder do
    it 'should be able to add embeds' do
      builder = Discordrb::Webhooks::Builder.new

      embed = builder.add_embed do |e|
        e.title = 'a'
        e.image = Discordrb::Webhooks::EmbedImage.new(url: 'https://example.com/image.png')
      end

      expect(builder.embeds.length).to eq 1
      expect(builder.embeds.first).to eq embed
    end
  end

  describe Discordrb::Webhooks::Embed do
    it 'should be able to have fields added' do
      embed = Discordrb::Webhooks::Embed.new

      embed.add_field(name: 'a', value: 'b', inline: true)

      expect(embed.fields.length).to eq 1
    end

    describe '#colour=' do
      it 'should accept colours in decimal format' do
        embed = Discordrb::Webhooks::Embed.new
        colour = 1234

        embed.colour = colour
        expect(embed.colour).to eq colour
      end

      it 'should raise if the colour value is too high' do
        embed = Discordrb::Webhooks::Embed.new
        colour = 100_000_000

        expect { embed.colour = colour }.to raise_error(ArgumentError)
      end

      it 'should accept colours in hex format' do
        embed = Discordrb::Webhooks::Embed.new
        colour = '162a3f'

        embed.colour = colour
        expect(embed.colour).to eq 1_452_607
      end

      it 'should accept colours in hex format with a # in front' do
        embed = Discordrb::Webhooks::Embed.new
        colour = '#162a3f'

        embed.colour = colour
        expect(embed.colour).to eq 1_452_607
      end

      it 'should accept colours as a RGB tuple' do
        embed = Discordrb::Webhooks::Embed.new
        colour = [22, 42, 63]

        embed.colour = colour
        expect(embed.colour).to eq 1_452_607
      end

      it 'should raise if a RGB tuple is of the wrong size' do
        embed = Discordrb::Webhooks::Embed.new

        expect { embed.colour = [0, 1] }.to raise_error(ArgumentError)
        expect { embed.colour = [0, 1, 2, 3] }.to raise_error(ArgumentError)
      end

      it 'should raise if a RGB tuple results in a too large value' do
        embed = Discordrb::Webhooks::Embed.new

        expect { embed.colour = [2000, 1, 2] }.to raise_error(ArgumentError)
      end
    end
  end
end
