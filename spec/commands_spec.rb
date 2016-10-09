require 'discordrb'

describe Discordrb::Commands do
  describe Discordrb::Commands::CommandBot do
    context 'no defined commands' do
      bot = Discordrb::Commands::CommandBot.new token: '', help_available: false

      it 'should successfully trigger the command' do
        event = double

        bot.execute_command(:test, event, [])
      end

      it 'should not send anything to the channel' do
        event = spy

        bot.execute_command(:test, event, [])

        expect(spy).to_not have_received :respond
      end
    end
  end
end
