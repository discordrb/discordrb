# frozen_string_literal: true

require 'discordrb'

describe Discordrb::Sticker do
  subject { described_class.new(sticker_args) }

  fixture :sticker_args, %i[sticker]

  describe '#initialize' do
    it 'returns an instance' do
      expect(subject).to be_a(described_class)
    end

    context 'sticker format type is invalid' do
      let(:invalid_format_type) { 'abc' }
      let(:bad_sticker_args) { sticker_args.merge({ 'format_type' => invalid_format_type }) }
      let(:bad_sticker_instance) { described_class.new(bad_sticker_args) }

      it 'raises an error' do
        puts bad_sticker_args
        expect { bad_sticker_instance }.to raise_error(ArgumentError)
      end
    end
  end

  describe '#name' do
    it 'returns the name' do
      expect(subject.name).to eq(sticker_args['name'])
    end
  end

  describe '#description' do
    it 'returns the description' do
      expect(subject.description).to eq(sticker_args['description'])
    end
  end

  describe '#tags' do
    it 'returns the tags' do
      expect(subject.tags).to eq(sticker_args['tags'])
    end
  end

  describe '#asset' do
    it 'returns the asset' do
      expect(subject.asset).to eq(sticker_args['asset'])
    end
  end

  describe '#asset' do
    it 'returns the asset' do
      expect(subject.asset).to eq(sticker_args['asset'])
    end
  end

  describe '#preview_asset' do
    it 'returns the preview_asset' do
      expect(subject.preview_asset).to eq(sticker_args['preview_asset'])
    end
  end

  describe '#format_type' do
    let(:format_type) { :apng }

    it 'returns the format_type' do
      expect(subject.format_type).to eq(format_type)
    end
  end
end
