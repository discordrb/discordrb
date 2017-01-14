require 'discordrb'

module Discordrb
  describe Bot do
    subject(:bot) do
      described_class.new(token: 'fake_token')
    end

    fixture :server_data, [:emoji, :emoji_server]
    fixture_property :server_id, :server_data, ['id'], :to_i

    # TODO: Use some way of mocking the API instead of setting the server to not exist
    let!(:server) { Discordrb::Server.new(server_data, bot, false) }

    fixture :dispatch_event, [:emoji, :dispatch_event]
    fixture :dispatch_add, [:emoji, :dispatch_add]

    fixture_property :emoji_1_name, :dispatch_add, ['emojis', 0, 'name']
    fixture_property :emoji_3_name, :dispatch_add, ['emojis', 2, 'name']

    fixture_property :emoji_1_id, :dispatch_add, ['emojis', 0, 'id'], :to_i
    fixture_property :emoji_2_id, :dispatch_add, ['emojis', 1, 'id'], :to_i
    fixture_property :emoji_3_id, :dispatch_add, ['emojis', 2, 'id'], :to_i

    fixture :dispatch_remove, [:emoji, :dispatch_remove]
    fixture :dispatch_update, [:emoji, :dispatch_update]

    fixture_property :edited_emoji_name, :dispatch_update, ['emojis', 1, 'name']

    before do
      bot.instance_variable_set(:@servers, server_id => server)
    end

    it 'should set up' do
      expect(bot.server(server_id)).to eq(server)
      expect(bot.server(server_id).emoji.size).to eq(2)
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
  end
end
