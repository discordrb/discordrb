# Pinging the bot will also tell you the time it takes the bot to send the message

require 'discordrb'

bot = Discordrb::Commands::CommandBot.new email: 'email@example.com', password: 'hunter2', prefix: '!'

bot.command(:ping) do |event|
  m = event.respond('Pong!')
  m.edit "Pong! Time taken: #{Time.now - event.timestamp} seconds."
  nil
end

bot.run
