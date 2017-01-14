require 'discordrb'

module Discordrb
  describe Bot do
    subject(:bot) do
      described_class.new(token: 'fake_token')
    end

    let!(:server) do
      Discordrb::Server.new(load_data_file(:emoji, :emoji_server), bot)
    end

    let!(:server_id) { server.id }

    # This data is represented in the fixtures (see ./data/emoji)
    EMOJI1_ID = 10
    EMOJI1_NAME = 'emoji_name_1'.freeze

    EMOJI2_ID = 11
    EMOJI2_NAME = 'emoji_name_2'.freeze
    EDITED_EMOJI_NAME = 'new_emoji_name'.freeze

    EMOJI3_ID = 12
    EMOJI3_NAME = 'emoji_name_3'.freeze

    before do
      bot.instance_variable_set(:@servers, server_id => server)
    end

    it 'should set up' do
      expect(bot.server(server_id)).to eq(server)
      expect(bot.server(server_id).emoji.size).to eq(2)
    end

    describe '#handle_dispatch' do
      it 'handles GUILD_EMOJIS_UPDATE' do
        data = load_data_file(:emoji, :dispatch_event)
        type = :GUILD_EMOJIS_UPDATE
        expect(bot).to receive(:raise_event).exactly(4).times
        bot.send(:handle_dispatch, type, data)
      end
    end

    describe '#update_guild_emoji' do
      it 'removes an emoji' do
        data = load_data_file(:emoji, :dispatch_remove)
        bot.send(:update_guild_emoji, data)
        emojis = bot.server(server_id).emoji
        emoji = emojis[EMOJI1_ID]
        expect(emojis.size).to eq(1)
        expect(emoji.name).to eq(EMOJI1_NAME)
        expect(emoji.server).to eq(server)
        expect(emoji.roles).to eq([])
      end

      it 'adds an emoji' do
        data = load_data_file(:emoji, :dispatch_add)
        bot.send(:update_guild_emoji, data)
        emojis = bot.server(server_id).emoji
        emoji = emojis[EMOJI3_ID]
        expect(emojis.size).to eq(3)
        expect(emoji.name).to eq(EMOJI3_NAME)
        expect(emoji.server).to eq(server)
        expect(emoji.roles).to eq([])
      end

      it 'edits an emoji' do
        data = load_data_file(:emoji, :dispatch_update)
        bot.send(:update_guild_emoji, data)
        emojis = bot.server(server_id).emoji
        emoji = emojis[EMOJI2_ID]
        expect(emojis.size).to eq(2)
        expect(emoji.name).to eq(EDITED_EMOJI_NAME)
        expect(emoji.server).to eq(server)
        expect(emoji.roles).to eq([])
      end
    end
  end
end
