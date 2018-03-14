require 'discordrb/webhooks'

describe Discordrb::Webhooks do
  describe Discordrb::Webhooks::Builder do
    it 'should be able to add embeds' do
      builder = Discordrb::Webhooks::Builder.new

      embed = builder.add_embed do |e|
        e.title = 'a'
        e.image = Discordrb::Webhooks::EmbedImage.new(url: 'http://some.url/image.png')
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

    describe 'Embed Limits' do
      it 'should raise if title length is over 256 characters' do
        embed = Discordrb::Webhooks::Embed.new

        expect { embed.title = nil }.not_to raise_error
        expect { embed.title = 'a' * 256 }.not_to raise_error
        expect { embed.title = 'a' * 257 }.to raise_error(ArgumentError)

        expect { Discordrb::Webhooks::Embed.new(title: nil) }.not_to raise_error
        expect { Discordrb::Webhooks::Embed.new(title: 'a' * 256) }.not_to raise_error
        expect { Discordrb::Webhooks::Embed.new(title: 'a' * 257) }.to raise_error(ArgumentError)
      end

      it 'should raise if description length is over 2048 characters' do
        embed = Discordrb::Webhooks::Embed.new

        expect { embed.description = nil }.not_to raise_error
        expect { embed.description = 'a' * 2048 }.not_to raise_error
        expect { embed.description = 'a' * 2049 }.to raise_error(ArgumentError)

        expect { Discordrb::Webhooks::Embed.new(description: nil) }.not_to raise_error
        expect { Discordrb::Webhooks::Embed.new(description: 'a' * 2048) }.not_to raise_error
        expect { Discordrb::Webhooks::Embed.new(description: 'a' * 2049) }.to raise_error(ArgumentError)
      end

      it 'should raise if number of fields must inside of 25' do
        embed = Discordrb::Webhooks::Embed.new

        field = Discordrb::Webhooks::EmbedField.new(name: 'a', value: 'a')

        expect { embed.fields = Array.new(25, field) }.not_to raise_error
        expect { embed.fields = Array.new(26, field) }.to raise_error(ArgumentError)

        expect { Discordrb::Webhooks::Embed.new(fields: Array.new(25, field)) }.not_to raise_error
        expect { Discordrb::Webhooks::Embed.new(fields: Array.new(26, field)) }.to raise_error(ArgumentError)
      end

      it 'should raise if field name length is over 246 characters' do
        field = Discordrb::Webhooks::EmbedField.new

        expect { field.name = 'a' * 256 }.not_to raise_error
        expect { field.name = 'a' * 257 }.to raise_error(ArgumentError)

        expect { Discordrb::Webhooks::EmbedField.new(name: 'a' * 256) }.not_to raise_error
        expect { Discordrb::Webhooks::EmbedField.new(name: 'a' * 257) }.to raise_error(ArgumentError)
      end

      it 'should raise if field value length is over 1024 characters' do
        field = Discordrb::Webhooks::EmbedField.new

        expect { field.value = 'a' * 1024 }.not_to raise_error
        expect { field.value = 'a' * 1025 }.to raise_error(ArgumentError)

        expect { Discordrb::Webhooks::EmbedField.new(value: 'a' * 1024) }.not_to raise_error
        expect { Discordrb::Webhooks::EmbedField.new(value: 'a' * 1025) }.to raise_error(ArgumentError)
      end

      it 'should raise if field name is empty' do
        field = Discordrb::Webhooks::EmbedField.new

        expect { field.name = 'a' }.not_to raise_error
        expect { field.name = '' }.to raise_error(ArgumentError)

        expect { Discordrb::Webhooks::EmbedField.new(name: 'a') }.not_to raise_error
        expect { Discordrb::Webhooks::EmbedField.new(name: '') }.to raise_error(ArgumentError)
      end

      it 'should raise if field value is empty' do
        field = Discordrb::Webhooks::EmbedField.new

        expect { field.value = 'a' }.not_to raise_error
        expect { field.value = '' }.to raise_error(ArgumentError)

        expect { Discordrb::Webhooks::EmbedField.new(value: 'a') }.not_to raise_error
        expect { Discordrb::Webhooks::EmbedField.new(value: '') }.to raise_error(ArgumentError)
      end

      it 'should raise if footer text length is over 2048 characters' do
        footer = Discordrb::Webhooks::EmbedFooter.new

        expect { footer.text = nil }.not_to raise_error
        expect { footer.text = 'a' * 2048 }.not_to raise_error
        expect { footer.text = 'a' * 2049 }.to raise_error(ArgumentError)

        expect { Discordrb::Webhooks::EmbedFooter.new(text: nil) }.not_to raise_error
        expect { Discordrb::Webhooks::EmbedFooter.new(text: 'a' * 2048) }.not_to raise_error
        expect { Discordrb::Webhooks::EmbedFooter.new(text: 'a' * 2049) }.to raise_error(ArgumentError)
      end

      it 'should raise if author name length is over 256 characters' do
        author = Discordrb::Webhooks::EmbedAuthor.new

        expect { author.name = nil }.not_to raise_error
        expect { author.name = 'a' * 256 }.not_to raise_error
        expect { author.name = 'a' * 257 }.to raise_error(ArgumentError)

        expect { Discordrb::Webhooks::EmbedAuthor.new(name: nil) }.not_to raise_error
        expect { Discordrb::Webhooks::EmbedAuthor.new(name: 'a' * 256) }.not_to raise_error
        expect { Discordrb::Webhooks::EmbedAuthor.new(name: 'a' * 257) }.to raise_error(ArgumentError)
      end

      it 'should raise if structure all characters over 6000 characters.' do
        # 6000 characters
        embed = Discordrb::Webhooks::Embed.new(
          fields: [
            Discordrb::Webhooks::EmbedField.new(name: 'a' * 100, value: 'b' * 900),
            Discordrb::Webhooks::EmbedField.new(name: 'a' * 100, value: 'b' * 900),
            Discordrb::Webhooks::EmbedField.new(name: 'a' * 100, value: 'b' * 900),
            Discordrb::Webhooks::EmbedField.new(name: 'a' * 100, value: 'b' * 900),
            Discordrb::Webhooks::EmbedField.new(name: 'a' * 100, value: 'b' * 900),
            Discordrb::Webhooks::EmbedField.new(name: 'a' * 100, value: 'b' * 900)
          ]
        )

        expect { embed.to_hash }.not_to raise_error
        embed.title = 'a'
        expect { embed.to_hash }.to raise_error(ArgumentError)
      end
    end
  end
end
