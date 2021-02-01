# frozen_string_literal: true

require 'discordrb'

describe Discordrb::Message do
  let(:server) { double('server') }
  let(:channel) { double('channel', server: server) }
  let(:token) { double('token') }
  let(:bot) { double('bot', channel: channel, token: token) }
  let(:server_id) { instance_double('String', 'server_id') }
  let(:channel_id) { instance_double('String', 'channel_id') }
  let(:message_id) { instance_double('String', 'message_id') }

  before do
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
  end

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
      data = message_data
      data['id'] = message_id
      data['guild_id'] = server_id
      data['channel_id'] = channel_id

      message = described_class.new(data, bot)
      expect(message.link).to eq 'https://discord.com/channels/server_id/channel_id/message_id'
    end

    it 'links to a private message' do
      data = message_data
      data['id'] = message_id
      data['guild_id'] = nil
      data['channel_id'] = channel_id

      message = described_class.new(data, bot)
      message.instance_variable_set(:@server, nil)

      expect(message.link).to eq 'https://discord.com/channels/@me/channel_id/message_id'
    end
  end

  describe '#reply!' do
    let(:message) { described_class.new(message_data, bot) }
    let(:content) { instance_double('String', 'content') }
    let(:mention) { instance_double('TrueClass', 'mention') }

    it 'responds with a message_reference' do
      expect(message).to receive(:respond).with(content, false, nil, nil, hash_including(:replied_user), message)

      message.reply!(content)
    end

    it 'sets replied_user in allowed_mentions' do
      expect(message).to receive(:respond).with(content, false, nil, nil, { replied_user: mention }, message)

      message.reply!(content, mention_user: mention)
    end

    context 'when allowed_mentions is false' do
      let(:mention) { double('mention') }

      it 'sets parse to an empty array add merges the mention_user param' do
        expect(message).to receive(:respond).with(content, false, nil, nil, { parse: [], replied_user: mention }, message)

        message.reply!(content, allowed_mentions: false, mention_user: mention)
      end
    end

    context 'when allowed_mentions is an AllowedMentions' do
      let(:hash) { instance_double('Hash', 'hash') }
      let(:allowed_mentions) { instance_double('Discordrb::AllowedMentions', 'allowed_mentions') }
      let(:mention_user) { instance_double('TrueClass', 'mention_user') }

      before do
        allow(allowed_mentions).to receive(:to_hash).and_return(hash)
        allow(hash).to receive(:transform_keys).with(any_args).and_return(hash)
        allow(hash).to receive(:[]=).with(:replied_user, mention_user)
      end

      it 'converts it to a hash to set the replied_user key' do
        expect(message).to receive(:respond).with(content, false, nil, nil, hash, message)
        message.reply!(content, allowed_mentions: allowed_mentions, mention_user: mention_user)
      end
    end
  end

  describe '#reply' do
    let(:message) { described_class.new(message_data, bot) }
    let(:content) { instance_double('String', 'content') }

    it 'sends a message to a channel' do
      expect(channel).to receive(:send_message).with(content)

      message.reply(content)
    end
  end

  describe '#respond' do
    let(:message) { described_class.new(message_data, bot) }
    let(:content) { instance_double('String', 'content') }
    let(:tts) { instance_double('TrueClass', 'tts') }
    let(:embed) { instance_double('Discordrb::Webhooks::Embed', 'embed') }
    let(:attachments) { instance_double('Array', 'attachments') }
    let(:allowed_mentions) { instance_double('Hash', 'allowed_mentions') }
    let(:message_reference) { instance_double('Discordrb::Message') }

    it 'forwards arguments to Channel#send_message' do
      expect(channel).to receive(:send_message).with(content, tts, embed, attachments, allowed_mentions, message_reference)

      message.respond(content, tts, embed, attachments, allowed_mentions, message_reference)
    end
  end
end
