require 'discordrb/webhooks'

describe Discordrb::Webhooks do
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
    end
  end
end
