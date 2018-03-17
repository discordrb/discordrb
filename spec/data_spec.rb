require 'discordrb'
require 'mock/api_mock'

using APIMock

module Discordrb
  describe Channel do
    let(:data) { load_data_file(:text_channel) }

    subject(:channel) do
      bot = double('bot')
      allow(bot).to receive(:token) { 'fake token' }
      described_class.new(data, bot, double('server'))
    end

    shared_examples 'a Channel property' do |property_name|
      it 'should call #update_channel_data' do
        expect(channel).to receive(:update_channel_data)
        channel.__send__("#{property_name}=", set_value)
      end

      it 'should change the cached value' do
        allow(channel).to receive(:update_channel_data) do |t|
          test_data = data.merge(t)
          channel.update_data(test_data)
        end
        channel.__send__("#{property_name}=", set_value)
        expect(channel.__send__(property_name)).to eq(test_value)
      end

      context 'when the API raises an error' do
        it 'should not change the cached value' do
          allow(channel).to receive(:update_channel_data).and_raise(Discordrb::Errors::NoPermission)
          begin
            channel.__send__("#{property_name}=", set_value)
          rescue Discordrb::Errors::NoPermission
            expect(channel.__send__(property_name)).to eq(default_value)
          end
        end
      end
    end

    describe '#name=' do
      let(:default_value) { data['name'] }
      let(:set_value) { 'Test' }
      let(:test_value) { 'Test' }
      it_behaves_like 'a Channel property', :name
    end

    describe '#topic=' do
      let(:default_value) { data['topic'] }
      let(:set_value) { 'Lorem ipsum dolor sit amet...' }
      let(:test_value) { 'Lorem ipsum dolor sit amet...' }
      it_behaves_like 'a Channel property', :topic
    end

    describe '#nsfw=' do
      context 'when toggled from false to true' do
        let(:default_value) { false }
        let(:set_value) { true }
        let(:test_value) { true }
        it_behaves_like 'a Channel property', :nsfw
      end

      context 'when toggled from true to false' do
        subject(:channel) do
          bot = double('bot')
          allow(bot).to receive(:token) { 'fake token' }
          described_class.new(data.merge('nsfw' => true), bot, double('server'))
        end
        let(:default_value) { true }
        let(:set_value) { false }
        let(:test_value) { false }
        it_behaves_like 'a Channel property', :nsfw
      end
    end

    describe '#permission_overwrites=' do
      context 'when permissions_overwrites are explicitly set' do
        let(:default_value) do
          data['permission_overwrites'].map { |el| [el['id'].to_i, Overwrite.from_hash(el)] }.to_h
        end
        test_data = { 'allow' => 0, 'deny' => 1, 'id' => '123', 'type' => 'role' }
        let(:set_value) { [test_data] }
        let(:test_value) { { test_data['id'].to_i => Overwrite.from_hash(test_data) } }
        it_behaves_like 'a Channel property', :permission_overwrites
      end

      context 'when permissions_overwrites are not set' do
        let(:topic) { 'test' }
        before do
          expect(API).to receive(:request).with(:channels_cid,
                                                kind_of(Numeric),
                                                :patch,
                                                instance_of(String),
                                                instance_of(String),
                                                instance_of(Hash)) do |*args|
            json = JSON.parse(args[4], symbolize_names: true)
            expect(json).to_not have_key(:permission_overwrites)
            data['topic'] = topic
            data.to_json
          end
        end

        it 'should not send permissions_overwrites in the API call' do
          subject.topic = topic
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

      it 'should fail with old messages in strict mode' do
        messages = [1, 2, 3]
        expect { channel.delete_messages(messages, true) }.to raise_error(ArgumentError)
      end

      it 'should remove old messages in non-strict mode' do
        allow(IDObject).to receive(:synthesise).and_return(4)
        messages = [1, 2, 3, 4]

        # Suppresses some noisy WARN logging from specs output
        allow(LOGGER).to receive(:warn)
        allow(API::Channel).to receive(:bulk_delete_messages)

        channel.delete_messages(messages)
        expect(messages).to eq [4]
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
