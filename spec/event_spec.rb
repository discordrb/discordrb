require 'discordrb'
require 'helpers'

RSpec.configure do |c|
  c.include Helpers
end

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
  end
end

module Discordrb::Events
  include Helpers

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

  describe ServerEvent do
    let(:bot) { double('bot', server: server) }
    let(:server) { double }

    subject(:event) do
      described_class.new({ SERVER_ID => nil }, bot)
    end

    it_behaves_like 'ServerEvent'
  end

  describe ServerEmojiCDEvent do
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

  describe ServerEmojiChangeEvent do
    let(:bot) { double }
    let(:server) { double('server', emoji: { EMOJI1_ID => nil, EMOJI2_ID => nil }) }

    subject(:event) do
      described_class.new(server, fake_emoji_data, bot)
    end

    it_behaves_like 'ServerEvent'

    describe '#process_emoji' do
      it 'sets an array of Emoji' do
        expect(event.emoji).to eq([nil, nil])
      end
    end
  end

  describe ServerEmojiUpdateEvent do
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
end
