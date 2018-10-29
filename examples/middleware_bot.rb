# frozen_string_literal: true

require 'discordrb'

# Enable middleware functionality:
require 'discordrb/middleware'
Discordrb::Bot.include(Discordrb::Middleware)

bot = Discordrb::Bot.new token: 'B0T.T0KEN.here'

# Middleware that only yields on specific channels.
# It can be configured to take channels by ID or by name per-handler.
class ChannelFilter
  def initialize(channels)
    @channels = Array(channels)
  end

  def call(event, _state)
    channel = event.channel

    matches = @channels.any? do |c|
      if c.is_a?(String)
        c.delete('#') == channel.name
      elsif c.is_a?(Integer)
        c.id == channel.id
      end
    end

    yield if matches
  end
end

# Middleware that parses incoming messages and stores the results
# in a state hash.
class Parser
  def initialize(prefix)
    @prefix = prefix
  end

  def call(event, state)
    split = event.message.content.split(' ')
    command = split[0]
    state[:command] = split[0][1..-1]
    state[:arguments] = split[1..-1]

    yield if command.start_with?(@prefix)
  end
end

# Apply a middleware to an event by passing it as an argument.
# This generates:
#   - !add 2 3 1 (responds 6)
#   - !ping (responds 'pong')
bot.message(Parser.new('!')) do |event, state|
  # Tap into the state hash set by your middleware:
  case state[:command]
  when 'add'
    event.respond state[:arguments].map { |i| Integer(i) }.sum
  when 'ping'
    event.respond 'pong'
  end
end

# Chain multiple middleware to create things like filters on certain
# conditions. The following will only work in a channel named "general",
# when the message starts with "?".
# This generates:
#   - ?info (responds 'made with discordrb')
#   - ?emoji (posts a random custom emoji)
bot.message(ChannelFilter.new('#general'), Parser.new('?')) do |event, state|
  case state[:command]
  when 'info'
    event.respond 'made with discordrb'
  when 'emoji'
    event.respond bot.emoji.sample.to_s
  end
end

# Fully compatible with exisitng event handler attributes. You specify them
# after your middleware chain, just note that they will be considered *first*,
# before your middleware is run.
# This handler will only run in a channel with a specific ID, and when your
# message starts with "foo".
bot.message(ChannelFilter.new(246283902652645376), start_with: 'foo') do |event|
  event.respond 'it works!'
end

# Use the same middleware on different kinds of events.
# This handler will be annoying inside channels named "annoying"
bot.typing(ChannelFilter.new('annoying')) do |event|
  event.respond "Hi #{event.user.mention}, I'm annoying!"
end

# Don't want to write a class for something simple?
# Write a proc literal:
bot.message(Parser.new('?rand'), ->(_e, _s, &b) { b.call if rand(2).even? }) do |event|
  event.respond 'lucky!'
end

bot.run
