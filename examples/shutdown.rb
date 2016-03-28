# This script allows you to shutdown the bot on command

require 'discordrb'

bot = Discordrb::Commands::CommandBot.new 'email@example.com', 'hunter2'

bot.command(:exit, help_available: false) do |event|
  unless event.user.id == 000000 # Replace number with your ID
    break
  end
  
  bot.send_message(event.channel.id, "Bot is shutting down")
  exit
end

bot.run
