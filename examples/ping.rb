# This simple bot responds to every "Ping!" message with a "Pong!"

require 'discordrb'

# This statement creates a bot with the specified token and application ID. After this line, you can add events to the
# created bot, and eventually run it.
#
# If you don't yet have a token and application ID to put in here, you will need to create a bot account here:
#   https://discordapp.com/developers/applications/me
# (If you're wondering about what redirect URIs and RPC origins, you can ignore those for now.)
# TODO: Add information describing those
# After creating the bot, simply copy the token (*not* the OAuth2 secret) and the client ID and put it into the
# respective places.
bot = Discordrb::Bot.new token: 'B0T.T0KEN.here', application_id: 160123456789876543

# Here we output the invite URL to the console so the bot account can be invited to the channel. This only has to be
# done once, afterwards, you can remove this part if you want
puts "This bot's invite URL is #{bot.invite_url}."
puts 'Click on it to invite it to your server.'

bot.message(with_text: 'Ping!') do |event|
  event.respond 'Pong!'
end

bot.run
