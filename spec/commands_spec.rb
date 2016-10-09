require 'discordrb'

describe Discordrb::Commands do
  describe Discordrb::Commands::CommandBot do
    it 'should allow no defined commands' do
      bot = Discordrb::Commands::CommandBot.new token: '', help_available: false

      event = spy

      bot.execute_command(:test, event, [])

      # We don't want anything sent to the channel
      expect(spy).to_not have_received :respond
    end
  end
end
