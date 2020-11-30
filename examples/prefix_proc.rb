# frozen_string_literal: true

require 'discordrb'

# Here, we'll demonstrate one way to achieve a dynamic command prefix
# in different contexts for your CommandBot.
# We'll use a frozen hash configuration, but you're free to implement
# any kind of lookup. (ex: server, channel, user, phase of the moon)

# Define a map of Channel ID => Prefix string.
# Here, we'll be using channel IDs so that it's easy to test in one server.
PREFIXES = {
  345687437722386433 => '!',
  83281822225530880 => '?'
}.freeze

# The CommandBot initializer accepts a Proc as a prefix, which will be
# evaluated with each message to parse the command string (the message)
# that gets passed to the internal command parser.
# We'll check what channel the message was in, get its prefix, and
# then strip the prefix from the message, as the internal parser determines
# what command to execute based off of the first word (the name of the command)
#
# The basic algorithm goes:
# 1. Command:
#      "!roll 1d6" (in channel 345687437722386433)
# 2. Get prefix:
#      PREFIXES[345687437722386433] #=> '!'
# 3. Remove prefix from the string, so we don't parse it:
#      content[prefix.size..-1] #=> "roll 1d6"
#
# You can of course define any behavior you like in here, such as a database
# lookup in SQL for example.
prefix_proc = proc do |message|
  # Since we may get commands in channels we didn't define a prefix for, we can
  # use a logical OR to set a "default prefix" for any other channel as
  # PREFIXES[] will return nil.
  prefix = PREFIXES[message.channel.id] || '.'

  # We use [prefix.size..-1] so we can handle prefixes of any length
  message.content[prefix.size..-1] if message.content.start_with?(prefix)
end

# Setup a new bot with our prefix proc
bot = Discordrb::Commands::CommandBot.new(token: 'token', prefix: prefix_proc)

# A simple dice roll command, use it like: '!roll 2d10'
bot.command(:roll, description: 'rolls some dice',
                   usage: 'roll NdS', min_args: 1) do |_event, dnd_roll|
  # Parse the input
  number, sides = dnd_roll.split('d')

  # Check for valid input; make sure we got both numbers
  next 'Invalid syntax.. try: `roll 2d10`' unless number && sides

  # Check for valid input; make sure we actually got numbers and not words
  begin
    number = Integer(number, 10)
    sides  = Integer(sides, 10)
  rescue ArgumentError
    next 'You must pass two *numbers*.. try: `roll 2d10`'
  end

  # Time to roll the dice!
  rolls = Array.new(number) { rand(1..sides) }
  sum = rolls.sum

  # Return the result
  "You rolled: `#{rolls}`, total: `#{sum}`"
end

bot.run
