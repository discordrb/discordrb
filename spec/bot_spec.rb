require 'discordrb'
require 'helpers'

RSpec.configure do |c|
  c.include Helpers
end

module Discordrb
  include Helpers
  describe Bot do
    subject(:bot) do
      described_class.new(token: 'fake_token')
    end

    let!(:server) do
      Discordrb::Server.new(load_data_file(:emoji, :emoji_server), bot)
    end

    let!(:server_id) { server.id }

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
        emoji_name = 'new_emoji_name'
        data = load_data_file(:emoji, :dispatch_update)
        bot.send(:update_guild_emoji, data)
        emojis = bot.server(server_id).emoji
        emoji = emojis[EMOJI2_ID]
        expect(emojis.size).to eq(2)
        expect(emoji.name).to eq(emoji_name)
        expect(emoji.server).to eq(server)
        expect(emoji.roles).to eq([])
      end
    end
  end
end
