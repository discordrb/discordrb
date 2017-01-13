require 'discordrb'
require 'mock/api_mock'

using APIMock

module Discordrb
  describe Channel do
    let(:data) { load_data_file(:text_channel) }

    subject(:channel) do
      bot = double('bot')
      allow(bot).to receive(:token) { 'fake token' }
      described_class.new(data, bot, double('server'))
    end

    describe '#delete_messages' do
      it 'should fail with more than 100 messages' do
        messages = [*1..101]
        expect { channel.delete_messages(messages) }.to raise_error(ArgumentError)
      end

      it 'should fail with less than 2 messages' do
        messages = [1]
        expect { channel.delete_messages(messages) }.to raise_error(ArgumentError)
      end

      it 'should fail with old messages in strict mode' do
        messages = [1, 2, 3]
        expect { channel.delete_messages(messages, true) }.to raise_error(ArgumentError)
      end
    end
  end
end
