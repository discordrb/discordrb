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
    end
  end
end
