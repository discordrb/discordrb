# This bot shows off PM functionality by sending a PM every time the bot is mentioned.

require 'discordrb'

bot = Discordrb::Bot.new "email@example.com", "hunter2"

bot.mention do |event|
  event.user.pm("You have mentioned me!")
end

bot.run
