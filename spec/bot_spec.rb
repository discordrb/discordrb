require 'discordrb'

RSpec.describe Discordrb::Bot do
  let(:gateway) { instance_double(Discordrb::Gateway) }
  let(:token) { '1234567abcdef' }
  let(:instance) { described_class.new(token: token) }

  before do
    instance.instance_variable_set(:@gateway, gateway)
    allow(gateway).to receive(:open?).and_return(true)
  end

  describe 'when changing the current state' do
    describe 'via #update_status' do
      context 'when changing only the game' do
        it 'attempts to send the new game' do
          expect(gateway).to receive(:send_status_update)
            .with(:online,
                  anything,
                  { name: 'new game', url: nil, type: nil },
                  anything)

          instance.update_status(:online, 'new game', nil)
        end
      end

      context 'when changing only the stream url' do
        it 'attempts to send the new stream url' do
          expect(gateway).to receive(:send_status_update)
            .with(:online,
                  anything,
                  { name: nil, url: 'new stream url', type: 1 },
                  anything)

          instance.update_status(:online, nil, 'new stream url')
        end
      end

      context 'when changing both the game and the stream url' do
        it 'attempts to send the new game object' do
          expect(gateway).to receive(:send_status_update)
            .with(:online,
                  anything,
                  { name: 'gamegame', url: 'new stream url', type: 1 },
                  anything)

          instance.update_status(:online, 'gamegame', 'new stream url')
        end
      end
    end

    describe 'via #game=' do
      it 'attempts to send the new game' do
        expect(gateway).to receive(:send_status_update)
          .with(:online,
                anything,
                { name: 'new game', url: nil, type: nil },
                anything)

        instance.game = 'new game'
      end

      context 'when clearing out the currently set game' do
        it 'sends a nil value upstream' do
          expect(gateway).to receive(:send_status_update)
            .with(:online,
                  anything,
                  { name: nil, url: nil, type: nil },
                  anything)

          instance.game = nil
        end
      end
    end

    describe 'via #stream' do
      it 'attempts to send the new stream url' do
        expect(gateway).to receive(:send_status_update)
          .with(:online,
                anything,
                { name: 'stream', url: 'url', type: 1 },
                anything)

        instance.stream('stream', 'url')
      end

      context 'when clearing out the currently set stream' do
        it 'sends a nil value upstream' do
          expect(gateway).to receive(:send_status_update)
            .with(:online,
                  anything,
                  { name: nil, url: nil, type: nil },
                  anything)

          instance.stream(nil, nil)
        end
      end
    end

    describe 'via #online' do
      it 'attempts to send the idle state' do
        expect(gateway).to receive(:send_status_update)
          .with(:idle, anything, anything, anything)

        instance.idle
      end

      context "when there's a game set" do
        before { allow(gateway).to receive(:send_status_update) }
        before { instance.game = 'my game' }

        it 'resends the current game' do
          expect(gateway).to receive(:send_status_update)
            .with(:idle,
                  anything,
                  { name: 'my game', url: nil, type: nil },
                  anything)

          instance.idle
        end
      end
    end

    describe 'via #idle' do
      it 'attempts to send the idle state' do
        expect(gateway).to receive(:send_status_update)
          .with(:online, anything, anything, anything)

        instance.online
      end

      context "when there's a game set" do
        before { allow(gateway).to receive(:send_status_update) }
        before { instance.game = 'my game' }

        it 'resends the current game' do
          expect(gateway).to receive(:send_status_update)
            .with(:idle,
                  anything,
                  { name: 'my game', url: nil, type: nil },
                  anything)

          instance.idle
        end
      end
    end

    describe 'via #dnd' do
      it 'attempts to send the idle state' do
        expect(gateway).to receive(:send_status_update)
          .with(:dnd, anything, anything, anything)

        instance.dnd
      end

      context "when there's a game set" do
        before { allow(gateway).to receive(:send_status_update) }
        before { instance.game = 'my game' }

        it 'resends the current game' do
          expect(gateway).to receive(:send_status_update)
            .with(:dnd,
                  anything,
                  { name: 'my game', url: nil, type: nil },
                  anything)

          instance.dnd
        end
      end
    end

    describe 'via #invisible' do
      it 'attempts to send the idle state' do
        expect(gateway).to receive(:send_status_update)
          .with(:invisible, anything, anything, anything)

        instance.invisible
      end

      context "when there's a game set" do
        before { allow(gateway).to receive(:send_status_update) }
        before { instance.game = 'my game' }

        it 'resends the current game' do
          expect(gateway).to receive(:send_status_update)
            .with(:invisible,
                  anything,
                  { name: 'my game', url: nil, type: nil },
                  anything)

          instance.invisible
        end
      end
    end
  end
end
