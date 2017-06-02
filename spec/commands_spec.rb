require 'discordrb'

describe Discordrb::Commands do
  describe Discordrb::Commands::CommandBot do
    def command_event_double
      event = double('event')
      allow(event).to receive :command=
      allow(event).to receive(:drain_into) { |e| e }

      event
    end

    context 'no defined commands' do
      bot = Discordrb::Commands::CommandBot.new token: '', help_available: false

      it 'should successfully trigger the command' do
        event = double

        bot.execute_command(:test, event, [], false, false)
      end

      it 'should not send anything to the channel' do
        event = spy

        bot.execute_command(:test, event, [], false, false)

        expect(spy).to_not have_received :respond
      end
    end

    context 'single command' do
      bot = Discordrb::Commands::CommandBot.new token: '', help_available: false

      RESPONSE = 'hi'.freeze

      bot.command :name do
        RESPONSE
      end

      context 'regular user' do
        it 'should return the response' do
          result = bot.execute_command(:name, command_event_double, [], false, false)

          expect(result).to eq RESPONSE
        end
      end
    end
  end
end
