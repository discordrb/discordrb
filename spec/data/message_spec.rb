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

  describe '#emoji' do
    it 'caches and returns only emojis from the message' do
      server_id = double(:server_id)
      channel_id = double(:channel_id)
      message_id = double(:message_id)

      allow(server_id).to receive(:to_i).and_return(server_id)
      allow(channel_id).to receive(:to_i).and_return(channel_id)
      allow(message_id).to receive(:to_i).and_return(message_id)

      allow(message_id).to receive(:to_s).and_return('message_id')
      allow(server_id).to receive(:to_s).and_return('server_id')
      allow(channel_id).to receive(:to_s).and_return('channel_id')

      allow(server).to receive(:id).and_return(server_id)
      allow(channel).to receive(:id).and_return(channel_id)
      allow(bot).to receive(:server).with(server_id).and_return(server)
      allow(bot).to receive(:channel).with(channel_id).and_return(channel)

      allow(server).to receive(:member)
      allow(channel).to receive(:private?)
      allow(channel).to receive(:text?)
      allow(bot).to receive(:ensure_user).with message_author

      emoji_a = Discordrb::Emoji.new({ 'name' => 'a', 'id' => 123 }, bot, server)
      emoji_b = Discordrb::Emoji.new({ 'name' => 'b', 'id' => 456 }, bot, server)

      allow(bot).to receive(:user).with('123').and_return(message_author)
      allow(bot).to receive(:channel).with('123', server).and_return(channel)
      allow(bot).to receive(:emoji).with('123').and_return(emoji_a)
      allow(bot).to receive(:emoji).with('456').and_return(emoji_b)
      allow(bot).to receive(:parse_mentions).and_return([message_author, channel, emoji_a, emoji_b])

      data = message_data
      data['id'] = message_id
      data['guild_id'] = server_id
      data['channel_id'] = channel_id

      message = described_class.new(data, bot)
      expect(message.emoji).to eq([emoji_a, emoji_b])
    end

    it 'calls Bot#parse_mentions once' do
      server_id = double(:server_id)
      channel_id = double(:channel_id)
      message_id = double(:message_id)

      allow(server_id).to receive(:to_i).and_return(server_id)
      allow(channel_id).to receive(:to_i).and_return(channel_id)
      allow(message_id).to receive(:to_i).and_return(message_id)

      allow(server).to receive(:id).and_return(server_id)
      allow(channel).to receive(:id).and_return(channel_id)
      allow(bot).to receive(:server).with(server_id).and_return(server)
      allow(bot).to receive(:channel).with(channel_id).and_return(channel)

      allow(server).to receive(:member)
      allow(channel).to receive(:private?)
      allow(channel).to receive(:text?)
      allow(bot).to receive(:ensure_user).with message_author

      emoji_a = Discordrb::Emoji.new({ 'name' => 'a', 'id' => 123 }, bot, server)
      emoji_b = Discordrb::Emoji.new({ 'name' => 'b', 'id' => 456 }, bot, server)

      allow(bot).to receive(:parse_mentions).once.and_return([emoji_a, emoji_b])

      data = message_data
      data['id'] = message_id
      data['guild_id'] = server_id
      data['channel_id'] = channel_id

      message = described_class.new(data, bot)
      message.emoji
      message.emoji
    end
  end

  describe '#link' do
    it 'links to a server message' do
      server_id = double(:server_id)
      channel_id = double(:channel_id)
      message_id = double(:message_id)

      allow(server_id).to receive(:to_i).and_return(server_id)
      allow(channel_id).to receive(:to_i).and_return(channel_id)
      allow(message_id).to receive(:to_i).and_return(message_id)

      allow(message_id).to receive(:to_s).and_return('message_id')
      allow(server_id).to receive(:to_s).and_return('server_id')
      allow(channel_id).to receive(:to_s).and_return('channel_id')

      allow(server).to receive(:id).and_return(server_id)
      allow(channel).to receive(:id).and_return(channel_id)
      allow(bot).to receive(:server).with(server_id).and_return(server)
      allow(bot).to receive(:channel).with(channel_id).and_return(channel)

      allow(server).to receive(:member)
      allow(channel).to receive(:private?)
      allow(channel).to receive(:text?)
      allow(bot).to receive(:ensure_user).with message_author

      data = message_data
      data['id'] = message_id
      data['guild_id'] = server_id
      data['channel_id'] = channel_id

      message = described_class.new(data, bot)
      expect(message.link).to eq 'https://discordapp.com/channels/server_id/channel_id/message_id'
    end

    it 'links to a private message' do
      channel_id = double(:channel_id)
      message_id = double(:message_id)

      allow(channel_id).to receive(:to_i).and_return(channel_id)
      allow(message_id).to receive(:to_i).and_return(message_id)

      allow(message_id).to receive(:to_s).and_return('message_id')
      allow(channel_id).to receive(:to_s).and_return('channel_id')

      allow(channel).to receive(:id).and_return(channel_id)
      allow(bot).to receive(:channel).with(channel_id).and_return(channel)

      allow(server).to receive(:member)
      allow(channel).to receive(:private?)
      allow(channel).to receive(:text?)
      allow(bot).to receive(:ensure_user).with message_author

      data = message_data
      data['id'] = message_id
      data['guild_id'] = nil
      data['channel_id'] = channel_id

      message = described_class.new(data, bot)
      expect(message.link).to eq 'https://discordapp.com/channels/@me/channel_id/message_id'
    end
  end
end
