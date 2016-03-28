# Gives you the ability to execute code on the fly

require 'discordrb'

bot = Discordrb::Commands::CommandBot.new 'email@example.com', 'hunter2'

bot.command(:eval, help_available: false) do |event, code|
  unless event.user.id == 0000 # Replace number with your ID
    break
  end
  begin
    eval(code)
  rescue
    "An error occured 😞"
  end
end

bot.run
