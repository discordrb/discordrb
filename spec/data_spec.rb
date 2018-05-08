require 'discordrb'
require 'mock/api_mock'

using APIMock

module Discordrb
  describe Channel do
    let(:data) { load_data_file(:text_channel) }
    let(:server) { double('server') }

    subject(:channel) do
      bot = double('bot')
      allow(bot).to receive(:token) { 'fake token' }
      described_class.new(data, bot, server)
    end

    shared_examples 'a Channel property' do |property_name|
      it 'should call #update_channel_data with data' do
        expect(channel).to receive(:update_channel_data).with(property_name => property_value)
        channel.__send__("#{property_name}=", property_value)
      end
    end

    describe '#name=' do
      it_behaves_like 'a Channel property', :name do
        let(:property_value) { double('name') }
      end
    end

    describe '#topic=' do
      it_behaves_like 'a Channel property', :topic do
        let(:property_value) { double('topic') }
      end
    end

    describe '#nsfw=' do
      context 'when toggled from false to true' do
        it_behaves_like 'a Channel property', :nsfw do
          let(:property_value) { true }
        end
      end

      context 'when toggled from true to false' do
        subject(:channel) { described_class.new(data.merge('nsfw' => true), double, double) }
        it_behaves_like 'a Channel property', :nsfw do
          let(:property_value) { false }
        end
      end
    end

    describe '#permission_overwrites=' do
      context 'when permissions_overwrites are explicitly set' do
        it_behaves_like 'a Channel property', :permission_overwrites do
          let(:property_value) { double('permission_overwrites') }
        end
      end
    end

    describe '#update_channel_data' do
      shared_examples('API call') do |property_name, num|
        it "should call the API with #{property_name}" do
          allow(channel).to receive(:update_data)
          allow(JSON).to receive(:parse)
          data = double(property_name)
          expectation = Array.new(num) { anything } << data << any_args
          expect(API::Channel).to receive(:update).with(*expectation)
          new_data = { property_name => data }
          channel.__send__(:update_channel_data, new_data)
        end
      end

      include_examples('API call', :name, 2)
      include_examples('API call', :topic, 3)
      include_examples('API call', :position, 4)
      include_examples('API call', :bitrate, 5)
      include_examples('API call', :user_limit, 6)
      include_examples('API call', :parent_id, 9)

      context 'when permission_overwrite are not set' do
        it 'should not send permission_overwrite' do
          allow(channel).to receive(:update_data)
          allow(JSON).to receive(:parse)
          new_data = double('new data')
          allow(new_data).to receive(:[])
          allow(new_data).to receive(:[]).with(:permission_overwrites).and_return(false)
          expect(API::Channel).to receive(:update).with(any_args, nil, anything)
          channel.__send__(:update_channel_data, new_data)
        end
      end

      context 'when passed a boolean for nsfw' do
        it 'should pass the boolean' do
          nsfw = double('nsfw')
          channel.instance_variable_set(:@nsfw, nsfw)
          allow(channel).to receive(:update_data)
          allow(JSON).to receive(:parse)
          new_data = double('new data')
          allow(new_data).to receive(:[])
          allow(new_data).to receive(:[]).with(:nsfw).and_return(1)
          expect(API::Channel).to receive(:update).with(any_args, nsfw, anything, anything)
          channel.__send__(:update_channel_data, new_data)
        end
      end

      context 'when passed a non-boolean for nsfw' do
        it 'should pass the cached value' do
          nsfw = double('nsfw')
          channel.instance_variable_set(:@nsfw, nsfw)
          allow(channel).to receive(:update_data)
          allow(JSON).to receive(:parse)
          new_data = double('new data')
          allow(new_data).to receive(:[])
          allow(new_data).to receive(:[]).with(:nsfw).and_return(1)
          expect(API::Channel).to receive(:update).with(any_args, nsfw, anything, anything)
          channel.__send__(:update_channel_data, new_data)
        end
      end

      it 'should call #update_data with new data' do
        response_data = double('new data')
        expect(channel).to receive(:update_data).with(response_data)
        allow(JSON).to receive(:parse).and_return(response_data)
        allow(API::Channel).to receive(:update)
        channel.__send__(:update_channel_data, double('data', :[] => double('sub_data', map: double)))
      end

      context 'when NoPermission is raised' do
        it 'should not call update_data' do
          allow(API::Channel).to receive(:update).and_raise(Discordrb::Errors::NoPermission)
          expect(channel).not_to receive(:update_data)
          begin
            channel.__send__(:update_channel_data, double('data', :[] => double('sub_data', map: double)))
          rescue Discordrb::Errors::NoPermission
            nil
          end
        end
      end
    end

    describe '#update_data' do
      shared_examples('update property data') do |property_name|
        context 'when we have new data' do
          it 'should assign the property' do
            new_data = double('new data', :[] => nil, :key? => true)
            test_data = double('test_data')
            allow(new_data).to receive(:[]).with(property_name).and_return(test_data)
            expect { channel.__send__(:update_data, new_data) }.to change { channel.__send__(property_name) }.to test_data
          end
        end
        context 'when we don\'t have new data' do
          it 'should keep the cached value' do
            new_data = double('new data', :[] => double('property'), key?: double)
            allow(new_data).to receive(:[]).with(property_name).and_return(nil)
            allow(new_data).to receive(:[]).with(property_name.to_s).and_return(nil)
            allow(channel).to receive(:process_permission_overwrites)
            expect { channel.__send__(:update_data, new_data) }.not_to(change { channel.__send__(property_name) })
          end
        end
      end

      include_examples('update property data', :name)
      include_examples('update property data', :topic)
      include_examples('update property data', :position)
      include_examples('update property data', :bitrate)
      include_examples('update property data', :user_limit)
      include_examples('update property data', :nsfw)
      include_examples('update property data', :parent_id)

      it 'should call process_permission_overwrites' do
        allow(API::Channel).to receive(:resolve).and_return('{}')
        expect(channel).to receive(:process_permission_overwrites)
        channel.__send__(:update_data)
      end

      context 'when data is not provided' do
        it 'should request it from the API' do
          expect(API::Channel).to receive(:resolve).and_return('{}')
          channel.__send__(:update_data)
        end
      end
    end

    describe '#delete_messages' do
      it 'should fail with more than 100 messages' do
        messages = [*1..101]
        expect { channel.delete_messages(messages) }.to raise_error(ArgumentError)
      end

      it 'should fail with less than 2 messages' do
        messages = [1]
        expect { channel.delete_messages(messages) }.to raise_error(ArgumentError)
      end

      it 'should resolve message ids' do
        message = double('message', resolve_id: double)
        num = 3
        messages = Array.new(num) { message } << 0
        allow(channel).to receive(:bulk_delete)
        expect(message).to receive(:resolve_id).exactly(num).times
        channel.delete_messages(messages)
      end

      it 'should call #bulk_delete' do
        messages = [1, 2, 3]
        expect(channel).to receive(:bulk_delete)
        channel.delete_messages(messages)
      end
    end

    describe '#bulk_delete' do
      it 'should log with old messages' do
        messages = [1, 2, 3, 4]
        allow(IDObject).to receive(:synthesise).and_return(3)
        allow(API::Channel).to receive(:bulk_delete_messages)
        expect(Discordrb::LOGGER).to receive(:warn).exactly(2).times
        channel.__send__(:bulk_delete, messages)
      end

      context 'when in strict mode' do
        it 'should raise ArgumentError with old messages' do
          messages = [1, 2, 3]
          expect { channel.__send__(:bulk_delete, messages, true) }.to raise_error(ArgumentError)
        end
      end

      context 'when in non-strict mode' do
        let('@bot'.to_sym) { double('bot', token: 'token') }

        it 'should remove old messages ' do
          allow(IDObject).to receive(:synthesise).and_return(4)
          messages = [1, 2, 3, 4]

          # Suppresses some noisy WARN logging from specs output
          allow(LOGGER).to receive(:warn)
          allow(API::Channel).to receive(:bulk_delete_messages)

          channel.__send__(:delete_messages, messages)
          expect(messages).to eq [4]
        end
      end
    end

    describe '#process_permission_overwrites' do
      it 'should assign permission overwrites' do
        overwrite = double('overwrite')
        element = { 'id' => 1 }
        overwrites = [element]
        allow(Overwrite).to receive(:from_hash).and_call_original
        allow(Overwrite).to receive(:from_hash).with(element).and_return(overwrite)
        channel.__send__(:process_permission_overwrites, overwrites)
        expect(channel.instance_variable_get(:@permission_overwrites)[1]).to eq(overwrite)
      end
    end

    describe '#sort_after' do
      it 'should call the API' do
        allow(server).to receive(:channels).and_return([])
        allow(server).to receive(:id).and_return(double)
        expect(API::Server).to receive(:update_channel_positions)

        channel.sort_after
      end

      it 'should only send channels of its own type' do
        channels = Array.new(10) { |i| double("channel #{i}", type: i % 4, parent_id: nil, position: i, id: i) }
        allow(server).to receive(:channels).and_return(channels)
        allow(server).to receive(:id).and_return(double)
        non_text_channels = channels.reject { |e| e.type == 0 }

        expect(API::Server).to receive(:update_channel_positions)
          .with(any_args, an_array_excluding(*non_text_channels.map{ |e| {id: e.id, position: instance_of(Integer)} }))
        channel.sort_after
      end

      it 'should send only the rearranged channels'

      it 'should return the new position'

      context 'when other is not on this server' do
        it 'should raise ArgumentError'
      end

      context 'when other is not of Channel, #resolve_id, nil' do
        it 'should raise TypeError'
      end

      context 'when position doesn\'t change' do
        it 'should not call the API'

        it 'should log a warning'
      end

      context 'when other channel is not the same type' do
        it 'should raise ArgumentError'
      end

      context 'when channel is not a category' do
        context 'and when changing category' do
          it 'should send new parent_id'

          context 'with lock_permissions as false and permissions different' do
            it 'should log that the permissions were not synced'
          end
        end
      end

      context 'when channel is a category' do
        it 'should raise ArgumentError on non-categories'

        it 'only send rearranged categories'
      end
    end
  end

  describe Message do
    let(:server) { double('server') }
    let(:channel) { double('channel', server: server) }
    let(:token) { double('token') }
    let(:bot) { double('bot', channel: channel, token: token) }

    fixture :message_data, %i[message]
    fixture_property :message_author, :message_data, ['author']

    describe '#initialize' do
      it 'caches an unavailable author' do
        allow(server).to receive(:member)
        allow(channel).to receive(:private?)
        allow(channel).to receive(:text?)

        # Bot will receive #ensure_user because the observed message author
        # is not present in the server cache, which is possible
        # (for example) if the author had left the server.
        expect(bot).to receive(:ensure_user).with message_author
        described_class.new(message_data, bot)
      end
    end
  end

  describe Role do
    let(:server) { double('server', id: double) }
    let(:bot) { double('bot', token: double) }

    subject(:role) do
      described_class.new(role_data, bot, server)
    end

    fixture :role_data, %i[role]

    describe '#sort_above' do
      context 'when other is nil' do
        it 'sorts the role to position 1' do
          allow(server).to receive(:update_role_positions)
          allow(server).to receive(:roles).and_return [
            double(id: 0, position: 0),
            double(id: 1, position: 1)
          ]

          new_position = role.sort_above
          expect(new_position).to eq 1
        end
      end

      context 'when other is given' do
        it 'sorts above other' do
          other = double(id: 1, position: 1, resolve_id: 1)
          allow(server).to receive(:update_role_positions)
          allow(server).to receive(:role).and_return other
          allow(server).to receive(:roles).and_return [
            double(id: 0, position: 0),
            other,
            double(id: 2, position: 2)
          ]

          new_position = role.sort_above(other)
          expect(new_position).to eq 2
        end
      end
    end
  end

  describe Emoji do
    let(:bot) { double('bot') }

    subject(:emoji) do
      server = double('server', role: double)

      described_class.new(emoji_data, bot, server)
    end

    fixture :emoji_data, %i[emoji]

    describe '#mention' do
      context 'with an animated emoji' do
        it 'serializes with animated flag' do
          allow(emoji).to receive(:animated).and_return(true)

          expect(emoji.mention).to eq '<a:rubytaco:315242245274075157>'
        end
      end

      it 'serializes' do
        expect(emoji.mention).to eq '<:rubytaco:315242245274075157>'
      end
    end
  end

  describe Webhook do
    let(:token) { double('token') }
    let(:reason) { double('reason') }
    let(:server) { double('server', member: double) }
    let(:channel) { double('channel', server: server) }
    let(:bot) { double('bot', channel: channel, token: token) }

    subject(:webhook) do
      described_class.new(webhook_data, bot)
    end

    fixture :webhook_data, %i[webhook]
    fixture_property :webhook_name, :webhook_data, ['name']
    fixture_property :webhook_channel_id, :webhook_data, ['channel_id'], :to_i
    fixture_property :webhook_id, :webhook_data, ['id'], :to_i
    fixture_property :webhook_token, :webhook_data, ['token']
    fixture_property :webhook_avatar, :webhook_data, ['avatar']

    fixture :update_name_data, %i[webhook update_name]
    fixture_property :edited_webhook_name, :update_name_data, ['name']

    fixture :update_avatar_data, %i[webhook update_avatar]
    fixture_property :edited_webhook_avatar, :update_channel_data, ['avatar']

    fixture :update_channel_data, %i[webhook update_channel]
    fixture_property :edited_webhook_channel_id, :update_channel_data, ['channel_id']

    fixture :avatar_data, %i[avatar]
    fixture_property :avatar_string, :avatar_data, ['avatar']

    describe '#initialize' do
      it 'sets readers' do
        expect(webhook.name).to eq webhook_name
        expect(webhook.id).to eq webhook_id
        expect(webhook.token).to eq webhook_token
        expect(webhook.avatar).to eq webhook_avatar
        expect(webhook.server).to eq server
        expect(webhook.channel).to eq channel
      end

      context 'when webhook from a token' do
        before { webhook.instance_variable_set(:@owner, nil) }
        it 'doesn\'t set owner' do
          expect(webhook.owner).to eq nil
        end
      end

      context 'when webhook is from auth' do
        context 'when owner cached' do
          let(:member) { double('member') }
          let(:server) { double('server', member: member) }

          it 'sets owner from cache' do
            expect(webhook.owner).to eq member
          end
        end

        context 'when owner not cached' do
          let(:server) { double('server', member: nil) }
          let(:user) { double('user') }
          let(:bot) { double('bot', channel: channel, ensure_user: user) }

          it 'gets user' do
            expect(webhook.owner).to eq user
          end
        end
      end
    end

    describe '#avatar=' do
      it 'calls update_webhook' do
        expect(webhook).to receive(:update_webhook).with(avatar: avatar_string)
        webhook.avatar = avatar_string
      end
    end

    describe '#delete_avatar' do
      it 'calls update_webhook' do
        expect(webhook).to receive(:update_webhook).with(avatar: nil)
        webhook.delete_avatar
      end
    end

    describe '#channel=' do
      it 'calls update_webhook' do
        expect(webhook).to receive(:update_webhook).with(channel_id: edited_webhook_channel_id.to_i)
        webhook.channel = edited_webhook_channel_id
      end
    end

    describe '#name=' do
      it 'calls update_webhook' do
        expect(webhook).to receive(:update_webhook).with(name: edited_webhook_name)
        webhook.name = edited_webhook_name
      end
    end

    describe '#update' do
      it 'calls update_webhook' do
        expect(webhook).to receive(:update_webhook).with(avatar: avatar_string, channel_id: edited_webhook_channel_id.to_i, name: edited_webhook_name, reason: reason)
        webhook.update(avatar: avatar_string, channel: edited_webhook_channel_id, name: edited_webhook_name, reason: reason)
      end
    end

    describe '#delete' do
      context 'when webhook is from auth' do
        it 'calls the API' do
          expect(API::Webhook).to receive(:delete_webhook).with(token, webhook_id, reason)
          webhook.delete(reason)
        end
      end

      context 'when webhook is from token' do
        before { webhook.instance_variable_set(:@owner, nil) }

        it 'calls the token API' do
          expect(API::Webhook).to receive(:token_delete_webhook).with(webhook_token, webhook_id, reason)
          webhook.delete(reason)
        end
      end
    end

    describe '#avatar_url' do
      context 'avatar is set' do
        it 'calls the correct API helper' do
          expect(API::User).to receive(:avatar_url).with(webhook_id, webhook_avatar)
          webhook.avatar_url
        end
      end

      context 'avatar is not set' do
        before { webhook.instance_variable_set(:@avatar, nil) }

        it 'calls the correct API helper' do
          expect(API::User).to receive(:default_avatar)
          webhook.avatar_url
        end
      end
    end

    describe '#inspect' do
      it 'describes the webhook' do
        expect(webhook.inspect).to eq "<Webhook name=#{webhook_name} id=#{webhook_id}>"
      end
    end

    describe '#token?' do
      context 'when webhook is from auth' do
        it 'returns false' do
          expect(webhook.token?).to eq false
        end
      end

      context 'when webhook is from token' do
        before { webhook.instance_variable_set(:@owner, nil) }
        it 'returns true' do
          expect(webhook.token?).to eq true
        end
      end
    end

    describe '#avatarise' do
      context 'avatar responds to read' do
        it 'returns encoded' do
          avatar = double('avatar', read: 'text')
          expect(webhook.send(:avatarise, avatar)).to eq "data:image/jpg;base64,#{Base64.strict_encode64('text')}"
        end
      end

      context 'avatar does not respond to read' do
        it 'returns itself' do
          avatar = double('avatar')
          expect(webhook.send(:avatarise, avatar)).to eq avatar
        end
      end
    end

    describe '#update_internal' do
      it 'sets name' do
        name = double('name')
        webhook.send(:update_internal, 'name' => name)
        expect(webhook.instance_variable_get(:@name)).to eq name
      end

      it 'sets avatar' do
        avatar = double('avatar')
        webhook.send(:update_internal, 'avatar' => avatar)
        expect(webhook.instance_variable_get(:@avatar_id)).to eq avatar
      end

      it 'sets channel' do
        channel = double('channel')
        channel_id = double('channel_id')
        allow(bot).to receive(:channel).with(channel_id).and_return(channel)
        webhook.send(:update_internal, 'channel_id' => channel_id)
        expect(webhook.instance_variable_get(:@channel)).to eq channel
      end
    end

    describe '#update_webhook' do
      context 'API returns valid data' do
        it 'calls update_internal' do
          webhook
          data = double('data', :[] => double)
          allow(JSON).to receive(:parse).and_return(data)
          allow(API::Webhook).to receive(:update_webhook)
          expect(webhook).to receive(:update_internal).with(data)
          webhook.send(:update_webhook, double('data', delete: reason))
        end
      end

      context 'API returns error' do
        it 'doesn\'t call update_internal' do
          webhook
          data = double('data', :[] => nil)
          allow(JSON).to receive(:parse).and_return(data)
          allow(API::Webhook).to receive(:update_webhook)
          expect(webhook).to_not receive(:update_internal)
          webhook.send(:update_webhook, double('data', delete: reason))
        end
      end

      context 'when webhook is from auth' do
        it 'calls auth API' do
          webhook
          data = double('data', delete: reason)
          allow(JSON).to receive(:parse).and_return(double('received_data', :[] => double))
          expect(API::Webhook).to receive(:update_webhook).with(token, webhook_id, data, reason)
          webhook.send(:update_webhook, data)
        end
      end

      context 'when webhook is from token' do
        before { webhook.instance_variable_set(:@owner, nil) }

        it 'calls token API' do
          data = double('data', delete: reason)
          allow(JSON).to receive(:parse).and_return(double('received_data', :[] => double))
          expect(API::Webhook).to receive(:token_update_webhook).with(webhook_token, webhook_id, data, reason)
          webhook.send(:update_webhook, data)
        end
      end
    end
  end
end
