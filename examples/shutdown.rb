# frozen_string_literal: true

# This bot doesn't do anything except for letting a specifically authorised user shutdown the bot on command.

require 'discordrb'

bot = Discordrb::Commands::CommandBot.new token: 'B0T.T0KEN.here', prefix: '!'

# Here we can see the `help_available` property used, which can determine whether a command shows up in the default
# generated `help` command. It is true by default but it can be set to false to hide internal commands that only
# specific people can use.
bot.command(:exit, help_available: false) do |event|
  # This is a check that only allows a user with a specific ID to execute this command. Otherwise, everyone would be
  # able to shut your bot down whenever they wanted.
  break unless event.user.id == 66237334693085184 # Replace number with your ID

  bot.send_message(event.channel.id, 'Bot is shutting down')
  exit
end

bot.run
