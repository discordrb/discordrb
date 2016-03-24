# This simple bot responds to every "Ping!" message with a "Pong!"

require 'discordrb'

bot = Discordrb::Bot.new token: 'B0T.T0KEN.here', application_id: 160123456789876543

bot.message(with_text: 'Ping!') do |event|
  event.respond 'Pong!'
end

bot.run
