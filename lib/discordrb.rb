require 'discordrb/version'
require 'discordrb/bot'
require 'discordrb/commands/command_bot'

# All discordrb functionality, to be extended by other files
module Discordrb
  Thread.current[:discordrb_name] = 'main'
end
