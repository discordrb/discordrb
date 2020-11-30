# frozen_string_literal: true

require 'discordrb'

describe Discordrb::Events do
  describe Discordrb::Events::Negated do
    it 'should initialize without errors' do
      Discordrb::Events::Negated.new(:test)
    end

    it 'should contain the passed object' do
      negated = Discordrb::Events::Negated.new(:test)
      expect(negated.object).to eq :test
    end
  end

  describe 'not!' do
    it 'should return a Negated object' do
      expect(not!(:test)).to be_a(Discordrb::Events::Negated)
    end

    it 'should contain the correct value' do
      expect(not!(:test).object).to eq :test
    end
  end

  describe 'matches_all' do
    it 'should return true for a nil attribute' do
      expect(Discordrb::Events.matches_all(nil, nil)).to eq true
    end

    it 'should be truthy if the block is truthy' do
      expect(Discordrb::Events.matches_all(:a, :e) { true }).to be_truthy
      expect(Discordrb::Events.matches_all(:a, :e) { 1 }).to be_truthy
      expect(Discordrb::Events.matches_all(:a, :e) { 0 }).to be_truthy
      expect(Discordrb::Events.matches_all(:a, :e) { 'string' }).to be_truthy
      expect(Discordrb::Events.matches_all(:a, :e) { false }).to_not be_truthy
    end

    it 'should be falsey if the block is falsey' do
      expect(Discordrb::Events.matches_all(:a, :e) { nil }).to be_falsy
      expect(Discordrb::Events.matches_all(:a, :e) { false }).to be_falsy
      expect(Discordrb::Events.matches_all(:a, :e) { 0 }).to_not be_falsy
    end

    it 'should correctly pass the arguments given' do
      Discordrb::Events.matches_all(:one, :two) do |a, e|
        expect(a).to eq(:one)
        expect(e).to eq(:two)
      end
    end

    it 'should correctly compare arguments for comparison blocks' do
      expect(Discordrb::Events.matches_all(1, 1) { |a, e| a == e }).to be_truthy
      expect(Discordrb::Events.matches_all(1, 0) { |a, e| a == e }).to be_falsy
      expect(Discordrb::Events.matches_all(0, 1) { |a, e| a == e }).to be_falsy
      expect(Discordrb::Events.matches_all(0, 0) { |a, e| a == e }).to be_truthy
      expect(Discordrb::Events.matches_all(1, 1) { |a, e| a != e }).to be_falsy
      expect(Discordrb::Events.matches_all(1, 0) { |a, e| a != e }).to be_truthy
      expect(Discordrb::Events.matches_all(0, 1) { |a, e| a != e }).to be_truthy
      expect(Discordrb::Events.matches_all(0, 0) { |a, e| a != e }).to be_falsy
    end

    it 'should return the opposite results for negated arguments' do
      expect(Discordrb::Events.matches_all(not!(:a), :e) { true }).to be_falsy
      expect(Discordrb::Events.matches_all(not!(:a), :e) { 1 }).to be_falsy
      expect(Discordrb::Events.matches_all(not!(:a), :e) { 0 }).to be_falsy
      expect(Discordrb::Events.matches_all(not!(:a), :e) { 'string' }).to be_falsy
      expect(Discordrb::Events.matches_all(not!(:a), :e) { false }).to_not be_falsy
      expect(Discordrb::Events.matches_all(not!(:a), :e) { nil }).to be_truthy
      expect(Discordrb::Events.matches_all(not!(:a), :e) { false }).to be_truthy
      expect(Discordrb::Events.matches_all(not!(:a), :e) { 0 }).to_not be_truthy
      expect(Discordrb::Events.matches_all(not!(1), 1) { |a, e| a == e }).to be_falsy
      expect(Discordrb::Events.matches_all(not!(1), 0) { |a, e| a == e }).to be_truthy
      expect(Discordrb::Events.matches_all(not!(0), 1) { |a, e| a == e }).to be_truthy
      expect(Discordrb::Events.matches_all(not!(0), 0) { |a, e| a == e }).to be_falsy
      expect(Discordrb::Events.matches_all(not!(1), 1) { |a, e| a != e }).to be_truthy
      expect(Discordrb::Events.matches_all(not!(1), 0) { |a, e| a != e }).to be_falsy
      expect(Discordrb::Events.matches_all(not!(0), 1) { |a, e| a != e }).to be_falsy
      expect(Discordrb::Events.matches_all(not!(0), 0) { |a, e| a != e }).to be_truthy
    end

    it 'should find one correct element inside arrays' do
      expect(Discordrb::Events.matches_all([1, 2, 3], 1) { |a, e| a == e }).to be_truthy
      expect(Discordrb::Events.matches_all([1, 2, 3], 2) { |a, e| a == e }).to be_truthy
      expect(Discordrb::Events.matches_all([1, 2, 3], 3) { |a, e| a == e }).to be_truthy
      expect(Discordrb::Events.matches_all([1, 2, 3], 4) { |a, e| a != e }).to be_truthy
    end

    it 'should return false when nothing matches inside arrays' do
      expect(Discordrb::Events.matches_all([1, 2, 3], 4) { |a, e| a == e }).to be_falsy
    end

    it 'should return the respective opposite results for negated arrays' do
      expect(Discordrb::Events.matches_all(not!([1, 2, 3]), 1) { |a, e| a == e }).to be_falsy
      expect(Discordrb::Events.matches_all(not!([1, 2, 3]), 2) { |a, e| a == e }).to be_falsy
      expect(Discordrb::Events.matches_all(not!([1, 2, 3]), 3) { |a, e| a == e }).to be_falsy
      expect(Discordrb::Events.matches_all(not!([1, 2, 3]), 4) { |a, e| a != e }).to be_falsy
      expect(Discordrb::Events.matches_all(not!([1, 2, 3]), 4) { |a, e| a == e }).to be_truthy
    end
  end

  describe Discordrb::Events::MessageEvent do
    let(:bot) { double }
    let(:channel) { double }
    let(:message) { double('message', channel: channel) }

    subject :event do
      described_class.new(message, bot)
    end

    describe 'after_call' do
      subject :handler do
        Discordrb::Events::MessageEventHandler.new(double, double('proc'))
      end

      it 'calls send_file with attached file, filename, and spoiler' do
        file = double(:file)
        filename = double(:filename)
        spoiler = double(:spoiler)
        allow(file).to receive(:is_a?).with(File).and_return(true)

        expect(event).to receive(:send_file).with(file, caption: '', filename: filename, spoiler: spoiler)
        event.attach_file(file, filename: filename, spoiler: spoiler)
        handler.after_call(event)
      end
    end
  end

  describe Discordrb::Events::EventHandler do
    describe 'matches?' do
      it 'should raise an error' do
        expect { Discordrb::Events::EventHandler.new({}, nil).matches?(nil) }.to raise_error(RuntimeError)
      end
    end
  end

  describe Discordrb::Events::TrueEventHandler do
    describe 'matches?' do
      it 'should return true' do
        expect(Discordrb::Events::TrueEventHandler.new({}, nil).matches?(nil)).to eq true
      end

      it 'should always call the block given' do
        count = 0
        Discordrb::Events::TrueEventHandler.new({}, proc { count += 1 }).match(nil)
        Discordrb::Events::TrueEventHandler.new({}, proc { count += 2 }).match(1)
        Discordrb::Events::TrueEventHandler.new({}, proc do |e|
          expect(e).to eq(1)
          count += 4
        end).match(1)
        Discordrb::Events::TrueEventHandler.new({ a: :b }, proc { count += 8 }).match(1)
        Discordrb::Events::TrueEventHandler.new(nil, proc { count += 16 }).match(1)
      end
    end
  end

  describe Discordrb::Events::MessageEventHandler do
    describe 'matches?' do
      it 'should call with empty attributes' do
        t = track('empty attributes')
        event = double('Discordrb::Events::MessageEvent')
        Discordrb::Events::MessageEventHandler.new({}, proc { t.track(1) }).match(event)
        # t.summary
      end
    end

    shared_examples 'end_with attributes' do |expr, matching, non_matching|
      describe 'end_with attribute' do
        it "matches #{matching}" do
          handler = Discordrb::Events::MessageEventHandler.new({ end_with: expr }, double('proc'))
          event = double('event', channel: double('channel', private?: false), author: double('author'), timestamp: double('timestamp'), content: matching)
          allow(event).to receive(:is_a?).with(Discordrb::Events::MessageEvent).and_return(true)
          expect(handler.matches?(event)).to be_truthy
        end

        it "doesn't match #{non_matching}" do
          handler = Discordrb::Events::MessageEventHandler.new({ end_with: expr }, double('proc'))
          event = double('event', channel: double('channel', private?: false), author: double('author'), timestamp: double('timestamp'), content: non_matching)
          allow(event).to receive(:is_a?).with(Discordrb::Events::MessageEvent).and_return(true)
          expect(handler.matches?(event)).to be_falsy
        end
      end
    end

    include_examples(
      'end_with attributes', /foo/, 'foo', 'f'
    )

    include_examples(
      'end_with attributes', /!$/, 'foo!', 'foo'
    )

    include_examples(
      'end_with attributes', /f(o)+/, 'foo', 'f'
    )

    include_examples(
      'end_with attributes', /e(fg)+(x(abba){1,2}x)*[stu]/i, 'abcdefgfgxabbaabbaxT', 'abcdefgfgxabbaabbaxT.'
    )

    include_examples(
      'end_with attributes', 'bar', 'foobar', 'foobarbaz'
    )
  end

  # This data is shared across examples, so it needs to be defined here
  # TODO: Refactor, potentially use `shared_context`
  # rubocop:disable Lint/ConstantDefinitionInBlock
  SERVER_ID = 1
  SERVER_NAME = 'server_name'
  EMOJI1_ID = 10
  EMOJI1_NAME = 'emoji_name_1'
  EMOJI2_ID = 11
  EMOJI2_NAME = 'emoji_name_2'
  # rubocop:enable Lint/ConstantDefinitionInBlock

  shared_examples 'ServerEvent' do
    describe '#initialize' do
      it 'sets bot' do
        expect(event.bot).to eq(bot)
      end
      it 'sets server' do
        expect(event.server).to eq(server)
      end
    end
  end

  shared_examples 'ServerEventHandler' do
    describe '#matches?' do
      it 'matches server names' do
        handler = described_class.new({ server: SERVER_NAME }, nil)
        expect(handler.matches?(event)).to be_truthy
      end

      it 'matches server ids' do
        handler = described_class.new({ server: SERVER_ID }, nil)
        expect(handler.matches?(event)).to be_truthy
      end

      it 'matches server object' do
        handler = described_class.new({ server: server }, nil)
        expect(handler.matches?(event)).to be_truthy
      end
    end
  end

  shared_examples 'ServerEmojiEventHandler' do
    describe '#matches?' do
      it 'matches emoji id' do
        handler = described_class.new({ id: EMOJI1_ID }, nil)
        expect(handler.matches?(event)).to be_truthy
      end

      it 'matches emoji name' do
        handler = described_class.new({ name: EMOJI1_NAME }, nil)
        expect(handler.matches?(event)).to be_truthy
      end
    end
  end

  describe Discordrb::Events::ServerEvent do
    let(:bot) { double('bot', server: server) }
    let(:server) { double }

    subject(:event) do
      described_class.new({ SERVER_ID => nil }, bot)
    end

    it_behaves_like 'ServerEvent'
  end

  describe Discordrb::Events::ServerEmojiCDEvent do
    let(:bot) { double }
    let(:server) { double }
    let(:emoji) { double }

    subject(:event) do
      described_class.new(server, emoji, bot)
    end

    it_behaves_like 'ServerEvent'

    describe '#initialize' do
      it 'sets emoji' do
        expect(event.emoji).to eq(emoji)
      end
    end
  end

  describe Discordrb::Events::ServerEmojiChangeEvent do
    fixture :dispatch, %i[emoji dispatch]

    fixture_property :emoji_1_id, :dispatch, ['emojis', 0, 'id'], :to_i
    fixture_property :emoji_2_id, :dispatch, ['emojis', 1, 'id'], :to_i

    let(:bot) { double }
    let(:server) { double('server', emoji: { emoji_1_id => nil, emoji_2_id => nil }) }

    subject(:event) do
      described_class.new(server, dispatch, bot)
    end

    it_behaves_like 'ServerEvent'

    describe '#process_emoji' do
      it 'sets an array of Emoji' do
        expect(event.emoji).to eq([nil, nil])
      end
    end
  end

  describe Discordrb::Events::ServerEmojiUpdateEvent do
    let(:bot) { double }
    let(:server) { double }
    let(:old_emoji) { double }
    let(:emoji) { double }

    subject(:event) do
      described_class.new(server, old_emoji, emoji, bot)
    end

    it_behaves_like 'ServerEvent'

    describe '#initialize' do
      it 'sets emoji' do
        expect(event.emoji).to eq(emoji)
      end
      it 'sets old_emoji' do
        expect(event.old_emoji).to eq(old_emoji)
      end
    end
  end

  describe Discordrb::Events::ServerEventHandler do
    let(:event) { double('event', is_a?: true, emoji: emoji, server: server) }
    let(:server) { double('server', name: SERVER_NAME, id: SERVER_ID) }
    let(:emoji) { double('emoji', id: EMOJI1_ID, name: EMOJI1_NAME) }

    it_behaves_like 'ServerEventHandler'
  end

  describe Discordrb::Events::ServerEmojiCDEventHandler do
    let(:event) { double('event', is_a?: true, emoji: emoji, server: server) }
    let(:server) { double('server', name: SERVER_NAME, id: SERVER_ID) }
    let(:emoji) { double('emoji', id: EMOJI1_ID, name: EMOJI1_NAME) }

    it_behaves_like 'ServerEventHandler'
    it_behaves_like 'ServerEmojiEventHandler'
  end

  describe Discordrb::Events::ServerEmojiUpdateEventHandler do
    let(:event) { double('event', is_a?: true, emoji: emoji_new, old_emoji: emoji_old, server: server) }
    let(:server) { double('server', name: SERVER_NAME, id: SERVER_ID) }
    let(:emoji_old) { double('emoji_old', id: EMOJI1_ID, name: EMOJI2_NAME) }
    let(:emoji_new) { double('emoji_new', name: EMOJI1_NAME) }

    it_behaves_like 'ServerEventHandler'
    it_behaves_like 'ServerEmojiEventHandler'

    describe '#matches?' do
      it 'matches old emoji name' do
        handler = described_class.new({ old_name: EMOJI2_NAME }, nil)
        expect(handler.matches?(event)).to be_truthy
      end
    end
  end
end
