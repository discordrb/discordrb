# frozen_string_literal: true

# For use with bundler:
# require 'rubygems'
# require 'bundler/setup'

require 'discordrb'

# Create a bot
bot = Discordrb::Bot.new token: 'B0T.T0KEN.here'

# Discordrb features an Awaits system that allows you to instantiate
# temporary event handlers. The following example depicts a simple
# "Guess the number" game using an await set up to listen for a specific
# user's follow-up messages until a condition is satisfied.
#
# Start the game by typing "!game" in chat.
bot.message(start_with: '!game') do |event|
  # Pick a number between 1 and 10
  magic = rand(1..10)

  # Tell the user that we're ready.
  event.respond "Can you guess my secret number? It's between 1 and 10!"

  # Await a MessageEvent specifically from the invoking user.
  # Timeout defines how long a user can spend playing one game.
  # This does not affect subsequent games.
  #
  # You can omit the options hash if you don't want a timeout.
  event.user.await!(timeout: 300) do |guess_event|
    # Their message is a string - cast it to an integer
    guess = guess_event.message.content.to_i

    # If the block returns anything that *isn't* true, then the
    # event handler will persist and continue to handle messages.
    if guess == magic
      # This returns `true`, which will destroy the await so we don't reply anymore
      guess_event.respond 'you win!'
      true
    else
      # Let the user know if they guessed too high or low.
      guess_event.respond(guess > magic ? 'too high' : 'too low')

      # Return false so the await is not destroyed, and we continue to listen
      false
    end
  end
  event.respond "My number was: `#{magic}`."
end

# Above we used the provided User#await! method to easily set up
# an await for a follow-up message from a user.
# We can also manually register an await for specific kinds of events.
# Here, we'll write a command that shows the current time and allows
# the user to delete the message with a reaction.
# We'll be using Bot#add_await! to do this:
# https://www.rubydoc.info/gems/discordrb/Discordrb%2FBot:add_await!

# the unicode ":x:" emoji
CROSS_MARK = "\u274c"

bot.message(content: '!time') do |event|
  # Send a message, and store a reference to it that we can add the reaction.
  message = event.respond "The current time is: #{Time.now.strftime('%F %T %Z')}"

  # React to the message to give a user an easy "button" to press
  message.react CROSS_MARK

  # Add an await for a ReactionAddEvent, that will only trigger for reactions
  # that match our CROSS_MARK emoji. To prevent the bot from cluttering up threads, we destroy the await after 30 seconds.
  bot.add_await!(Discordrb::Events::ReactionAddEvent, message: message, emoji: CROSS_MARK, timeout: 30) do |_reaction_event|
    message.delete # Delete the bot message
  end
  # This code executes after our await concludes, or when the timeout runs out.
  # For demonstration purposes, it just prints "Await destroyed.". In your actual code you might want to edit the message or something alike.
  puts 'Await destroyed.'
end

# Connect to Discord
bot.run

# For more details about Awaits, see:
# https://www.rubydoc.info/gems/discordrb/Discordrb/Await
# For a list of events you can use to await for, see:
# https://www.rubydoc.info/gems/discordrb/Discordrb/Events
