# frozen_string_literal: true

require 'discordrb'

describe Discordrb::Bot do
  subject(:bot) do
    described_class.new(token: 'fake_token')
  end

  fixture :server_data, %i[emoji emoji_server]
  fixture_property :server_id, :server_data, ['id'], :to_i

  # TODO: Use some way of mocking the API instead of setting the server to not exist
  let!(:server) { Discordrb::Server.new(server_data, bot, false) }

  fixture :dispatch_event, %i[emoji dispatch_event]
  fixture :dispatch_add, %i[emoji dispatch_add]

  fixture_property :emoji_1_name, :dispatch_add, ['emojis', 0, 'name']
  fixture_property :emoji_3_name, :dispatch_add, ['emojis', 2, 'name']

  fixture_property :emoji_1_id, :dispatch_add, ['emojis', 0, 'id'], :to_i
  fixture_property :emoji_2_id, :dispatch_add, ['emojis', 1, 'id'], :to_i
  fixture_property :emoji_3_id, :dispatch_add, ['emojis', 2, 'id'], :to_i

  fixture :dispatch_remove, %i[emoji dispatch_remove]
  fixture :dispatch_update, %i[emoji dispatch_update]

  fixture_property :edited_emoji_name, :dispatch_update, ['emojis', 1, 'name']

  before do
    bot.instance_variable_set(:@servers, server_id => server)
  end

  it 'should set up' do
    expect(bot.server(server_id)).to eq(server)
    expect(bot.server(server_id).emoji.size).to eq(2)
  end

  it 'raises when token string is empty or nil' do
    expect { described_class.new(token: '') }.to raise_error('Token string is empty or nil')
    expect { described_class.new(token: nil) }.to raise_error('Token string is empty or nil')
  end

  describe '#parse_mentions' do
    it 'parses user mentions' do
      user_a = double(:user_a)
      user_b = double(:user_b)
      allow(bot).to receive(:user).with('123').and_return(user_a)
      allow(bot).to receive(:user).with('456').and_return(user_b)
      mentions = bot.parse_mentions('<@!123><@!456>', server)
      expect(mentions).to eq([user_a, user_b])
    end

    it 'parses channel mentions' do
      channel_a = double(:channel_a)
      channel_b = double(:channel_b)
      allow(bot).to receive(:channel).with('123', server).and_return(channel_a)
      allow(bot).to receive(:channel).with('456', server).and_return(channel_b)
      mentions = bot.parse_mentions('<#123><#456>', server)
      expect(mentions).to eq([channel_a, channel_b])
    end

    it 'parses role mentions' do
      role_a = double(:role_a)
      role_b = double(:role_b)
      allow(server).to receive(:role).with('123').and_return(role_a)
      allow(server).to receive(:role).with('456').and_return(role_b)
      mentions = bot.parse_mentions('<@&123><@&456>')
      expect(mentions).to eq([role_a, role_b])
    end

    it 'parses emoji mentions' do
      emoji_a = double(:emoji_a)
      emoji_b = double(:emoji_b)
      allow(bot).to receive(:emoji).with('123').and_return(emoji_a)
      allow(bot).to receive(:emoji).with('456').and_return(emoji_b)
      mentions = bot.parse_mentions('<a:foo:123><a:bar:456>')
      expect(mentions).to eq([emoji_a, emoji_b])
    end

    it "doesn't parse invalid mentions" do
      mentions = bot.parse_mentions('<<@123<@?123><#123<:foo:123<b:foo:456><@abc><@!abc>', server)
      expect(mentions).to eq []
    end
  end

  describe '#parse_mention' do
    context 'with an uncached emoji' do
      it 'returns an emoji with the available data' do
        allow(bot).to receive(:emoji)
        string = '<a:foo:123>'
        emoji = bot.parse_mention(string)
        expect([emoji.name, emoji.id, emoji.animated]).to eq ['foo', 123, true]
      end
    end
  end

  describe '#handle_dispatch' do
    it 'handles GUILD_EMOJIS_UPDATE' do
      type = :GUILD_EMOJIS_UPDATE
      expect(bot).to receive(:raise_event).exactly(4).times
      bot.send(:handle_dispatch, type, dispatch_event)
    end
  end

  describe '#update_guild_emoji' do
    it 'removes an emoji' do
      bot.send(:update_guild_emoji, dispatch_remove)

      emojis = bot.server(server_id).emoji
      emoji = emojis[emoji_1_id]

      expect(emojis.size).to eq(1)
      expect(emoji.name).to eq(emoji_1_name)
      expect(emoji.server).to eq(server)
      expect(emoji.roles).to eq([])
    end

    it 'adds an emoji' do
      bot.send(:update_guild_emoji, dispatch_add)

      emojis = bot.server(server_id).emoji
      emoji = emojis[emoji_3_id]

      expect(emojis.size).to eq(3)
      expect(emoji.name).to eq(emoji_3_name)
      expect(emoji.server).to eq(server)
      expect(emoji.roles).to eq([])
    end

    it 'edits an emoji' do
      bot.send(:update_guild_emoji, dispatch_update)

      emojis = bot.server(server_id).emoji
      emoji = emojis[emoji_2_id]

      expect(emojis.size).to eq(2)
      expect(emoji.name).to eq(edited_emoji_name)
      expect(emoji.server).to eq(server)
      expect(emoji.roles).to eq([])
    end
  end

  describe '#send_file' do
    let(:channel) { double(:channel, resolve_id: double) }

    it 'defines original_filename when filename is passed' do
      original_filename = double(:original_filename)
      file = double(:file, original_filename: original_filename, read: true)
      new_filename = double('new filename')

      allow(Discordrb::API::Channel).to receive(:upload_file).and_return('{}')
      allow(Discordrb::Message).to receive(:new)

      bot.send_file(channel, file, filename: new_filename)
      expect(file.original_filename).to eq new_filename
    end

    it 'does not define original_filename when filename is nil' do
      original_filename = double(:original_filename)
      file = double(:file, read: true, original_filename: original_filename)

      allow(Discordrb::API::Channel).to receive(:upload_file).and_return('{}')
      allow(Discordrb::Message).to receive(:new)

      bot.send_file(channel, file)
      expect(file.original_filename).to eq original_filename
    end

    it 'prepends "SPOILER_" when spoiler is truthy and the filename does not start with "SPOILER_"' do
      file = double(:file, read: true)

      allow(Discordrb::API::Channel).to receive(:upload_file).and_return('{}')
      allow(Discordrb::Message).to receive(:new)

      bot.send_file(channel, file, filename: 'file.txt', spoiler: true)
      expect(file.original_filename).to eq 'SPOILER_file.txt'
    end

    it 'does not prepend "SPOILER_" when spoiler is truthy if filename.start_with? "SPOILER_"' do
      file = double(:file, read: true)
      original_filename = double(:original_filename)

      allow(original_filename).to receive(:start_with?).with('SPOILER_').and_return(true)
      allow(Discordrb::API::Channel).to receive(:upload_file).and_return('{}')
      allow(Discordrb::Message).to receive(:new)

      bot.send_file(channel, file, filename: original_filename, spoiler: true)
      expect(file.original_filename).to eq original_filename
    end

    it 'uses the original filename when spoiler is truthy and filename is nil' do
      file = double(:file, read: true, path: 'file.txt')

      allow(Discordrb::API::Channel).to receive(:upload_file).and_return('{}')
      allow(Discordrb::Message).to receive(:new)

      bot.send_file(channel, file, spoiler: true)
      expect(file.original_filename).to eq 'SPOILER_file.txt'
    end
  end
end
