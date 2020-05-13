# frozen_string_literal: true

require 'discordrb'

describe Discordrb::Commands::CommandBot, order: :defined do
  SIMPLE_RESPONSE = 'hi'
  TEST_CHANNELS = [
    1,
    2,
    '3',
    'channel-four',
    '#channel-five'
  ].freeze

  let(:text_channel_data) { load_data_file(:text_channel) }
  let(:default_channel_id) { 123 }
  let(:default_channel_name) { 'test-channel' }
  let(:user_id) { 321 }
  let(:user_roles) { [load_data_file(:text_channel), load_data_file(:text_channel)] }
  let(:role_1) { user_roles[0].tap { |r| r['id'] = 240_172_879_361_212_417 }['id'] } # So we don't have the same ID in both roles.
  let(:role_2) { user_roles[1]['id'].to_i }
  let(:test_channels) { TEST_CHANNELS }
  let(:first_channel) { test_channels[0] }
  let(:second_channel) { test_channels[1] }
  let(:third_channel) { test_channels[2] }
  let(:fourth_channel) { test_channels[3] }
  let(:fifth_channel) { test_channels[4] }
  let(:sixth_channel) do
    bot = double('bot')
    allow(bot).to receive(:token) { 'fake token' }
    Discordrb::Channel.new(text_channel_data, bot, double('server'))
  end

  def command_event_double
    double('event').tap do |event|
      allow(event).to receive :command=
      allow(event).to receive(:drain_into) { |e| e }
      allow(event).to receive(:server)
      allow(event).to receive(:channel)
    end
  end

  def append_author_to_double(event)
    allow(event).to receive(:author) do
      double('member').tap do |member|
        allow(member).to receive(:id) { user_id }
        allow(member).to receive(:roles) { user_roles }
        allow(member).to receive(:permission?) { true }
        allow(member).to receive(:webhook?) { false }
      end
    end
    allow(event).to receive(:user) do
      double('user').tap do |user|
        allow(user).to receive(:id) { user_id }
        allow(user).to receive(:webhook?) { false }
      end
    end
  end

  def append_bot_to_double(event)
    allow(event).to receive(:bot) do
      double('bot').tap do |bot|
        allow(bot).to receive(:token) { 'fake token' }
        allow(bot).to receive(:rate_limited?) { false }
        allow(bot).to receive(:attributes) { {} }
      end
    end
  end

  def append_channel_to_double(event, channel_id, **kwargs)
    data = text_channel_data.dup.merge kwargs
    data['id'] = channel_id
    data['name'] = kwargs.fetch(:name) { default_channel_name }
    channel = Discordrb::Channel.new(data, event.bot, double('server'))
    allow(event).to receive(:channel) { channel }
  end

  def command_event_double_for_channel(channel_id = default_channel_id, **kwargs)
    command_event_double.tap do |event|
      append_author_to_double(event)
      append_bot_to_double(event)
      append_channel_to_double(event, channel_id, kwargs)
    end
  end

  def command_event_double_with_channel(channel)
    command_event_double.tap do |event|
      append_author_to_double(event)
      append_bot_to_double(event)
      allow(event).to receive(:channel) { channel }
    end
  end

  context 'no defined commands' do
    bot = Discordrb::Commands::CommandBot.new token: 'token', help_available: false

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
    bot = Discordrb::Commands::CommandBot.new token: 'token', help_available: false

    bot.command :name do
      SIMPLE_RESPONSE
    end

    context 'regular user' do
      it 'should return the response' do
        result = bot.execute_command(:name, command_event_double, [], false, false)

        expect(result).to eq SIMPLE_RESPONSE
      end
    end
  end

  describe ':help_command' do
    context 'without custom :help_message' do
      it 'should print the default :help_message' do
        bot = Discordrb::Commands::CommandBot.new(token: 'token')
        bot.command(:name) { SIMPLE_RESPONSE }
        result = bot.execute_command(:help, command_event_double_with_channel(first_channel), [], false, false)

        expect(result).to eq "**List of commands:**\n**`help`**: Shows a list of all the commands available or displays help for a specific command.\n**`name`**: *No description available*\n"
      end
    end
    context 'with custom :Help_message' do
      it 'should print the custom :help_message' do
        bot = Discordrb::Commands::CommandBot.new(token: 'token', help_message: "Custom Help Message")
        bot.command(:name) { SIMPLE_RESPONSE }
        result = bot.execute_command(:help, command_event_double_with_channel(first_channel), [], false, false)

        expect(result).to eq "Custom Help Message\n**`help`**: Shows a list of all the commands available or displays help for a specific command.\n**`name`**: *No description available*\n"
      end
    end
  end

  describe '#execute_command', order: :defined do
    context 'with role filter', order: :defined do
      bot = Discordrb::Commands::CommandBot.new(token: 'token', help_available: false)

      describe 'required_roles' do
        before do
          # User has both roles.
          bot.command :user_has_all, required_roles: [role_1, role_2] do
            SIMPLE_RESPONSE
          end

          # User has only one of two roles.
          bot.command :user_has_one, required_roles: [role_1, 123] do
            SIMPLE_RESPONSE
          end
        end

        it 'responds when the user has all the roles', skip: true do
          plain_event = command_event_double_for_channel(first_channel)
          result = bot.execute_command(:user_has_all, plain_event, [])
          expect(result).to eq SIMPLE_RESPONSE
        end

        it 'does not respond with one role missing', skip: true do
          plain_event = command_event_double_with_channel(first_channel)
          result = bot.execute_command(:user_has_one, plain_event, [])
          expect(result).to eq nil
        end
      end

      describe 'allowed_roles' do
        before do
          # User has one role.
          bot.command :user_has_one, required_roles: [role_1, 123] do
            SIMPLE_RESPONSE
          end

          # User doesn't have any.
          bot.command :user_has_none, required_roles: [123, 456] do
            SIMPLE_RESPONSE
          end
        end

        it 'responds when the user has at least one role', skip: true do
          plain_event = command_event_double_with_channel(first_channel)
          result = bot.execute_command(:user_has_one, plain_event, [])
          expect(result).to eq SIMPLE_RESPONSE
        end

        it 'does not respond to a user with none of the roles' do
          plain_event = command_event_double_with_channel(first_channel)
          result = bot.execute_command(:any_role, plain_event, [])
          expect(result).to eq nil
        end
      end
    end

    context 'with channel filter', order: :defined do
      context 'when list is not initialized in bot parameters', order: :defined do
        bot = Discordrb::Commands::CommandBot.new(token: 'token', help_available: false)

        bot.command :name do
          SIMPLE_RESPONSE
        end

        it 'has no channels' do
          expect(bot.attributes[:channels]).to be_empty
        end

        it 'responds in any channel when no channel list is provided' do
          test_channels.each do |channel|
            plain_event = command_event_double_for_channel(channel)
            result = bot.execute_command(:name, plain_event, [])
            expect(result).to eq SIMPLE_RESPONSE
          end
        end

        it 'can have channels added' do
          bot.add_channel(first_channel)
          expect(bot.attributes[:channels]).to contain_exactly(first_channel)
        end

        it 'responds only in added channels' do
          plain_event1 = command_event_double_for_channel(first_channel)
          result = bot.execute_command(:name, plain_event1, [])
          expect(result).to eq SIMPLE_RESPONSE
        end

        it 'does not have channels that were not added' do
          expect(bot.attributes[:channels]).not_to include(second_channel, third_channel)
        end

        it 'does not respond in channels not added' do
          plain_event2 = command_event_double_for_channel(second_channel)
          result = bot.execute_command(:name, plain_event2, [])
          expect(result).to be_nil

          plain_event3 = command_event_double_for_channel(third_channel)
          result = bot.execute_command(:name, plain_event3, [])
          expect(result).to be_nil
        end
      end

      context 'when list is initialized in bot parameters', order: :defined do
        bot = Discordrb::Commands::CommandBot.new(token: 'token', help_available: false, channels: [TEST_CHANNELS[0]])

        bot.command :name do
          SIMPLE_RESPONSE
        end

        it 'has the initial channels' do
          expect(bot.attributes[:channels]).to contain_exactly(first_channel)
        end

        it 'responds in listed channels' do
          event_listed = command_event_double_for_channel(first_channel)
          result = bot.execute_command(:name, event_listed, [])
          expect(result).to eq SIMPLE_RESPONSE
        end

        it 'does not respond in unlisted channels' do
          event_unlisted = command_event_double_for_channel(second_channel)
          result = bot.execute_command(:name, event_unlisted, [])
          expect(result).to be_nil
        end

        it 'has both initial and added channels' do
          bot.add_channel(second_channel)
          expect(bot.attributes[:channels]).to contain_exactly(first_channel, second_channel)
        end

        it 'responds in all added channels' do
          event_listed = command_event_double_for_channel(first_channel)
          result = bot.execute_command(:name, event_listed, [])
          expect(result).to eq SIMPLE_RESPONSE

          event_added = command_event_double_for_channel(second_channel)
          result = bot.execute_command(:name, event_added, [])
          expect(result).to eq SIMPLE_RESPONSE
        end

        it 'removes channels' do
          bot.remove_channel(first_channel)
          expect(bot.attributes[:channels]).to contain_exactly(second_channel)
        end

        it 'does not respond in removed channels' do
          event_removed = command_event_double_for_channel(first_channel)
          result = bot.execute_command(:name, event_removed, [])
          expect(result).to be_nil
        end

        it 'responds in all channels when the last channel is removed' do
          bot.remove_channel(second_channel)

          test_channels.each do |channel|
            plain_event = command_event_double_for_channel(channel)
            result = bot.execute_command(:name, plain_event, [])
            expect(result).to eq SIMPLE_RESPONSE
          end
        end
      end

      context 'listed as a channel name', order: :defined do
        bot = Discordrb::Commands::CommandBot.new(token: 'token', help_available: false)

        bot.command :name do
          SIMPLE_RESPONSE
        end

        it 'allows adding a channel by name' do
          bot.add_channel(fourth_channel)
          expect(bot.attributes[:channels]).to contain_exactly(fourth_channel)
        end

        it 'responds when channel name is used' do
          event = command_event_double_for_channel(name: fourth_channel)
          result = bot.execute_command(:name, event, [])
          expect(result).to eq SIMPLE_RESPONSE
        end

        it 'does not modify the channel list while responding to a channel name' do
          expect(bot.attributes[:channels]).to contain_exactly(fourth_channel)
        end

        it 'does not respond for unlisted channels using channel name' do
          event = command_event_double_for_channel(name: fifth_channel)
          result = bot.execute_command(:name, event, [])
          expect(result).to be_nil
        end
      end

      context 'listed as an object', order: :defined do
        bot = Discordrb::Commands::CommandBot.new(token: 'token', help_available: false)

        bot.command :name do
          SIMPLE_RESPONSE
        end

        it 'allows adding a channel object' do
          bot.add_channel(sixth_channel)
          expect(bot.attributes[:channels]).to contain_exactly(sixth_channel)
        end

        it 'responds when channel objects are used' do
          event = command_event_double_with_channel(sixth_channel)
          result = bot.execute_command(:name, event, [])
          expect(result).to eq SIMPLE_RESPONSE
        end

        it 'does not modify the list while respond to a channel object' do
          expect(bot.attributes[:channels]).to contain_exactly(sixth_channel)
        end

        it 'does not respond in unlisted channels' do
          event = command_event_double_for_channel(first_channel)
          result = bot.execute_command(:name, event, [])
          expect(result).to be_nil
        end
      end

      context 'command_bot#channels=', order: :defined do
        bot = Discordrb::Commands::CommandBot.new(token: 'token', help_available: false, channels: [TEST_CHANNELS[0], TEST_CHANNELS[1]])

        bot.command :name do
          SIMPLE_RESPONSE
        end

        it 'new channels should replace old channels' do
          bot.channels = [third_channel, sixth_channel]
          expect(bot.attributes[:channels]).to contain_exactly(third_channel, sixth_channel)
        end

        it 'responds only in the new channels' do
          event = command_event_double_for_channel(third_channel)
          result = bot.execute_command(:name, event, [])
          expect(result).to eq SIMPLE_RESPONSE
        end

        it 'does not respond in old channels' do
          event = command_event_double_for_channel(first_channel)
          result = bot.execute_command(:name, event, [])
          expect(result).to be_nil
        end
      end
    end
  end
end
