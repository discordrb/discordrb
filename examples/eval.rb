# Gives you the ability to execute code on the fly

require 'discordrb'

bot = Discordrb::Commands::CommandBot.new email: 'email@example.com', password: 'hunter2', prefix: '!'

bot.command(:eval, help_available: false) do |event, *code|
  break unless event.user.id == 000000 # Replace number with your ID

  begin
    eval code.join(' ')
  rescue
    "An error occured 😞"
  end
end

bot.run
