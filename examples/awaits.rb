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

# Above we used the provided User#await method to easily set up
# an await for a follow-up message from a user.
# We can also manually register an await for specific kinds of events.
# Here, we'll write a command that shows the current time and allows
# the user to delete the message with a reaction.
# We'll be using Bot#add_await to do this:
# http://www.rubydoc.info/gems/discordrb/Discordrb%2FBot:add_await

# the unicode ":x:" emoji
CROSS_MARK = "\u274c".freeze

bot.message(content: '!time') do |event|
  # Send a message, and store a reference to it that we can issue a delete request later
  message = event.respond "The current time is: #{Time.now.strftime('%F %T %Z')}"

  # React to the message to give a user an easy "button" to press
  message.react CROSS_MARK

  # Add an await for a ReactionAddEvent, that will only trigger for reactions
  # that match our CROSS_MARK emoji. This time, I'm using interpolation to make the
  # await key unique for this event so that multiple awaits can exist.
  bot.add_await(:"delete_#{message.id}", Discordrb::Events::ReactionAddEvent, emoji: CROSS_MARK) do |reaction_event|
    # Since this code will run on every CROSS_MARK reaction, it might not
    # be on our time message we sent earlier. We use `next` to skip the rest
    # of the block unless it was our message that was reacted to.
    next true unless reaction_event.message.id == message.id

    # Delete the matching message.
    message.delete
  end
end

# Connect to Discord
bot.run

# For more details about Awaits, see:
# http://www.rubydoc.info/gems/discordrb/Discordrb/Await
# For a list of events you can use to await for, see:
# http://www.rubydoc.info/gems/discordrb/Discordrb/Events
