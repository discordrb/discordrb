require 'discordrb'

bot = Discordrb::Commands::CommandBot.new token: 'B0T.T0KEN.here', application_id: 160123456789876543, prefix: '!'

bot.command(:connect) do |event|
  # The `voice_channel` method returns the voice channel the user is currently in, or `nil` if the user is not in a
  # voice channel.
  channel = event.user.voice_channel

  # Here we return from the command unless the channel is not nil (i. e. the user is in a voice channel). The `next`
  # construct can be used to exit a command prematurely, and even send a message while we're at it.
  next "You're not in any voice channel!" unless channel

  # The `voice_connect` method does everything necessary for the bot to connect to a voice channel. Afterwards the bot
  # will be connected and ready to play stuff back.
  bot.voice_connect(channel)
  "Connected to voice channel: #{channel.name}"
end

# A simple command that plays back an mp3 file.
bot.command(:play_mp3) do |event|
  # `event.voice` is a helper method that gets the correct voice bot on the server the bot is currently in. Since a
  # bot may be connected to more than one voice channel (never more than one on the same server, though), this is
  # necessary to allow the differentiation of servers.
  #
  # It returns a `VoiceBot` object that methods such as `play_file` can be called on.
  voice_bot = event.voice
  voice_bot.play_file('data/music.mp3')
end

# DCA is a custom audio format developed by a couple people from the Discord API community (including myself, meew0).
# It represents the audio data exactly as Discord wants it in a format that is very simple to parse, so libraries can
# very easily add support for it. It has the advantage that absolutely no transcoding has to be done, so it is very
# light on CPU in comparison to `play_file`.
bot.command(:play_mp3) do |event|
  voice_bot = event.voice
  voice_bot.play_dca('data/music.dca')
end

bot.run
