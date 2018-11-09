# frozen_string_literal: true

require 'discordrb'

describe Discordrb::Message do
  let(:server) { double('server') }
  let(:channel) { double('channel', server: server) }
  let(:token) { double('token') }
  let(:bot) { double('bot', channel: channel, token: token) }

  fixture :message_data, %i[message]
  fixture_property :message_author, :message_data, ['author']

  describe '#initialize' do
    it 'caches an unavailable author' do
      allow(server).to receive(:member)
      allow(channel).to receive(:private?)
      allow(channel).to receive(:text?)

      # Bot will receive #ensure_user because the observed message author
      # is not present in the server cache, which is possible
      # (for example) if the author had left the server.
      expect(bot).to receive(:ensure_user).with message_author
      described_class.new(message_data, bot)
    end
  end
end
