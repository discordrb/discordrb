# frozen_string_literal: true

unless ENV['DISCORDRB_V2_MESSAGE']
  puts "You're using version 2 of discordrb which has some breaking changes!"
  puts "Don't worry if your bot crashes, you can find a list and migration advice here:"
  puts ' https://github.com/meew0/discordrb/blob/master/CHANGELOG.md#200'
  puts 'This message will go away in version 2.1 or can be disabled by setting the DISCORDRB_V2_MESSAGE environment variable.'
end

require 'discordrb/version'
require 'discordrb/bot'
require 'discordrb/commands/command_bot'
require 'discordrb/logger'

# All discordrb functionality, to be extended by other files
module Discordrb
  Thread.current[:discordrb_name] = 'main'

  # The default debug logger used by discordrb.
  LOGGER = Logger.new(ENV['DISCORDRB_FANCY_LOG'])
end

# In discordrb, Integer and {String} are monkey-patched to allow for easy resolution of IDs
class Integer
  # @return [Integer] The Discord ID represented by this integer, i. e. the integer itself
  def resolve_id
    self
  end
end

# In discordrb, {Integer} and String are monkey-patched to allow for easy resolution of IDs
class String
  # @return [Integer] The Discord ID represented by this string, i. e. the string converted to an integer
  def resolve_id
    to_i
  end
end
