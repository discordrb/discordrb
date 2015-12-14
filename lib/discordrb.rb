require 'discordrb/version'
require 'discordrb/bot'
require 'discordrb/commands/command_bot'
require 'discordrb/logger'

# All discordrb functionality, to be extended by other files
module Discordrb
  Thread.current[:discordrb_name] = 'main'

  LOGGER = Logger.new
end
