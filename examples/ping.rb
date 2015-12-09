# This simple bot responds to every "Ping!" message with a "Pong!"

require 'discordrb'

bot = Discordrb::Bot.new 'email@example.com', 'hunter2'

bot.message(with_text: 'Ping!') do |event|
  event.respond 'Pong!'
end

bot.run
