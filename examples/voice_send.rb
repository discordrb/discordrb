require 'discordrb'

bot = Discordrb::Commands::CommandBot.new token: 'B0T.T0KEN.here', application_id: 160123456789876543, prefix: '!'

bot.command(:connect) do |event|
  channel = event.user.voice_channel

  bot.voice_connect(channel)
  "Connected to voice channel: #{channel.name}"
end

bot.run
