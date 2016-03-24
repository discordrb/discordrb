# This bot has various commands that show off CommandBot.

require 'discordrb'

bot = Discordrb::Commands::CommandBot.new token: 'B0T.T0KEN.here', application_id: 160123456789876543, prefix: '!'

bot.command :user do |event|
  event.user.name
end

bot.command :bold do |_event, *args|
  "**#{args.join(' ')}**"
end

bot.command :italic do |_event, *args|
  "**#{args.join(' ')}**"
end

bot.command(:join, permission_level: 1, chain_usable: false) do |event, invite|
  event.bot.join invite
end

bot.command(:random, min_args: 0, max_args: 2, description: 'Generates a random number between 0 and 1, 0 and max or min and max.', usage: 'random [min/max] [max]') do |_event, min, max|
  if max
    rand(min.to_i..max.to_i)
  elsif min
    rand(0..min.to_i)
  else
    rand
  end
end

bot.command :long do |event|
  event << 'This is a long message.'
  event << 'It has multiple lines that are each sent by doing `event << line`.'
  event << 'This is an easy way to do such long messages, or to create lines that should only be sent conditionally.'
  event << 'Anyway, have a nice day.'
end

bot.run
