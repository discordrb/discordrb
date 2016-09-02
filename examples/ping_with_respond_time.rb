# This example is nearly the same as the normal ping example, but rather than simply responding with "Pong!", it also
# responds with the time it took to send the message.

require 'discordrb'

bot = Discordrb::Bot.new token: 'B0T.T0KEN.here', application_id: 160123456789876543

bot.message(content: 'Ping!') do |event|
  m = event.respond('Pong!')
  m.edit "Pong! Time taken: #{Time.now - event.timestamp} seconds."
end

bot.run
