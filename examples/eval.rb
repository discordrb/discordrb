# frozen_string_literal: true

# Eval bots are useful for developers because they give you a way to execute code directly from your Discord channel,
# e.g. to quickly check something, demonstrate something to other, or something else entirely. Special care must be
# taken since anyone with access to the command can execute arbitrary code on your system which may potentially be
# malicious.

require 'discordrb'

bot = Discordrb::Commands::CommandBot.new token: 'B0T.T0KEN.here', prefix: '!'

bot.command(:eval, help_available: false) do |event, *code|
  break unless event.user.id == 66237334693085184 # Replace number with your ID

  begin
    eval code.join(' ')
  rescue StandardError
    'An error occurred 😞'
  end
end

bot.run
