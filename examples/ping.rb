# This simple bot responds to every "Ping!" message with a "Pong!"

require 'discordrb'

# This statement creates a bot with the specified token and application ID. After this line, you can add events to the
# created bot, and eventually run it.
bot = Discordrb::Bot.new token: 'B0T.T0KEN.here', application_id: 160123456789876543

# Here we output the invite URL to the console so the bot account can be invited to the channel. This only has to be
# done once, afterwards, you can remove this part if you want
puts "This bot's invite URL is #{bot.invite_url}."
puts 'Click on it to invite it to your server.'

bot.message(with_text: 'Ping!') do |event|
  event.respond 'Pong!'
end

bot.run
