# This bot shows off PM functionality by sending a PM every time the bot is mentioned.

require 'discordrb'

bot = Discordrb::Bot.new token: 'B0T.T0KEN.here', application_id: 160123456789876543

# The `mention` event is called if the bot is *directly mentioned*, i.e. not using a role mention or @everyone/@here.
bot.mention do |event|
  event.user.pm('You have mentioned me!')
end

bot.run
