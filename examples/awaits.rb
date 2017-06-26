require 'discordrb'

# Create a bot
bot = Discordrb::Bot.new token: 'token'

# Discordrb features an Awaits system that allows you to instantiate
# temporary event handlers. The following example depicts a simple
# "Guess the number" game using an await set up to listen for a specific
# user's follow-up messages until a condition is satisfied.
#
# Start the game by typing "!game" in chat.
bot.message(start_with: '!game') do |event|
  # Pick a number between 1 and 10
  magic = rand(1..10)

  # Await a MessageEvent specifically from the invoking user.
  #
  # Note that since the identifier I'm using here is `:guess`,
  # only one person can be playing at one time. You can otherwise
  # interpolate something into a symbol to have multiple awaits
  # for this "command" available at the same time.
  event.user.await(:guess) do |guess_event|
    # Their message is a string - cast it to an integer
    guess = guess_event.message.content.to_i

    # If the block returns anything that *isn't* `false`, then the
    # event handler will persist and continue to handle messages.
    if guess == magic
      # This returns `nil`, which will destroy the await so we don't reply anymore
      guess_event.respond 'you win!'
    else
      # Let the user know if they guessed too high or low.
      guess_event.respond(guess > magic ? 'too high' : 'too low')

      # Return false so the await is not destroyed, and we continue to listen
      false
    end
  end

  # Let the user know we're  ready and listening..
  event.respond 'Guess a number between 1 and 10..'
end

# Connect to Discord
bot.run

# For more details about Awaits, see:
# http://www.rubydoc.info/gems/discordrb/Discordrb/Await
