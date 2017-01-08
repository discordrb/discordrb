require 'discordrb'

describe Discordrb do
  it 'should split messages correctly' do
    split = Discordrb.split_message('a' * 5234)
    expect(split).to eq(['a' * 2000, 'a' * 2000, 'a' * 1234])

    # regression test
    # there had been an issue where this would have raised an error,
    # and (if it hadn't raised) produced incorrect results
    split = Discordrb.split_message(('a' * 800 + "\n") * 6)
    expect(split).to eq([
                          'a' * 800 + "\n" + 'a' * 800 + "\n",
                          'a' * 800 + "\n" + 'a' * 800 + "\n",
                          'a' * 800 + "\n" + 'a' * 800
                        ])
  end

  describe Discordrb::Bot do
    SERVER_ID = 1
    EMOJI1_ID = 10
    EMOJI1_NAME = 'emoji_name'.freeze
    EMOJI2_ID = 11
    EMOJI2_NAME = 'emoji_name_2'.freeze
    EMOJI3_ID = 12
    EMOJI3_NAME = 'emoji_name_3'.freeze

    let!(:bot) { Discordrb::Bot.new(token: '') }

    let!(:server) do
      fake_server_data = JSON.parse(%({ "verification_level": 0, "features": [], "emojis": [{"roles":[],"require_colons":true,"name":"#{EMOJI1_NAME}","managed":false,"id":"#{EMOJI1_ID}"}, {"roles":[],"require_colons":true,"name":"#{EMOJI2_NAME}","managed":false,"id":"#{EMOJI2_ID}"}] }))
      Discordrb::Server.new(fake_server_data, bot)
    end

    before do
      bot.instance_variable_set(:@servers, SERVER_ID => server)
    end

    it 'should set up' do
      expect(bot.server(SERVER_ID)).to eq(server)
      expect(bot.server(SERVER_ID).emoji.size).to eq(2)
    end

    describe '#update_guild_emoji' do
      it 'removes an emoji' do
        fake_emoji_data = JSON.parse(%({"guild_id":"#{SERVER_ID}","emojis":[{"roles":[],"require_colons":true,"name":"#{EMOJI1_NAME}","managed":false,"id":"#{EMOJI1_ID}"}]}))
        bot.send(:update_guild_emoji, fake_emoji_data)
        emojis = bot.server(SERVER_ID).emoji
        emoji = emojis[EMOJI1_ID]
        expect(emojis.size).to eq(1)
        expect(emoji.name).to eq(EMOJI1_NAME)
        expect(emoji.server).to eq(server)
        expect(emoji.roles).to eq([])
      end

      it 'adds an emoji' do
        fake_emoji_data = JSON.parse(%({"guild_id":"#{SERVER_ID}","emojis":[{"roles":[],"require_colons":true,"name":"#{EMOJI1_NAME}","managed":false,"id":"#{EMOJI1_ID}"},{"roles":[],"require_colons":true,"name":"#{EMOJI2_NAME}","managed":false,"id":"#{EMOJI2_ID}"},{"roles":[],"require_colons":true,"name":"#{EMOJI3_NAME}","managed":false,"id":"#{EMOJI3_ID}"}]}))
        bot.send(:update_guild_emoji, fake_emoji_data)
        emojis = bot.server(SERVER_ID).emoji
        emoji = emojis[EMOJI3_ID]
        expect(emojis.size).to eq(3)
        expect(emoji.name).to eq(EMOJI3_NAME)
        expect(emoji.server).to eq(server)
        expect(emoji.roles).to eq([])
      end

      it 'edits an emoji' do
        emoji_name = 'new_emoji_name'
        fake_emoji_data = JSON.parse(%({"guild_id":"#{SERVER_ID}","emojis":[{"roles":[],"require_colons":true,"name":"#{EMOJI1_NAME}","managed":false,"id":"#{EMOJI1_ID}"},{"roles":[],"require_colons":true,"name":"#{emoji_name}","managed":false,"id":"#{EMOJI2_ID}"}]}))
        bot.send(:update_guild_emoji, fake_emoji_data)
        emojis = bot.server(SERVER_ID).emoji
        emoji = emojis[EMOJI2_ID]
        expect(emojis.size).to eq(2)
        expect(emoji.name).to eq(emoji_name)
        expect(emoji.server).to eq(server)
        expect(emoji.roles).to eq([])
      end
    end
  end
end
