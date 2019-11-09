# frozen_string_literal: true

require 'discordrb'

describe Discordrb::Emoji do
  subject(:emoji) do
    server = double('server', role: double)

    described_class.new(emoji_data, server)
  end

  fixture :emoji_data, %i[emoji]

  describe '#mention' do
    context 'with an animated emoji' do
      it 'serializes with animated flag' do
        allow(emoji).to receive(:animated).and_return(true)

        expect(emoji.mention).to eq '<a:rubytaco:315242245274075157>'
      end
    end

    it 'serializes' do
      expect(emoji.mention).to eq '<:rubytaco:315242245274075157>'
    end
  end

  describe '#to_reaction' do
    it 'serializes to reaction format' do
      expect(emoji.to_reaction).to eq 'rubytaco:315242245274075157'
    end

    context 'when ID is nil' do
      it 'serializes to reaction format without custom emoji ID character' do
        allow(emoji).to receive(:id).and_return(nil)

        expect(emoji.to_reaction).to eq 'rubytaco'
      end
    end
  end
end
