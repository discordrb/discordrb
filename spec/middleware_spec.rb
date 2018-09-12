require 'discordrb'
require 'discordrb/middleware'

describe Discordrb::Middleware::Stack do
  describe '#run' do
    it 'calls each middleware' do
      a_called = false
      b_called = false

      middleware = [
        lambda do |_, _, &block|
          a_called = true
          block.call
        end,
        lambda do |_, _, &block|
          b_called = true
          block.call
        end
      ]
      stack = described_class.new(middleware)
      stack.run(double)

      expect(a_called && b_called).to eq true
    end

    it "stops when a middleware doesn't yield" do
      a_called = false
      b_called = false

      middleware = [
        lambda do |_, _|
          a_called = true
        end,
        lambda do |_, _, &block|
          b_called = true
          block.call
        end
      ]
      stack = described_class.new(middleware)
      stack.run(double)

      expect(a_called && b_called).to eq false
    end

    it 'calls a passed block at the end of the chain' do
      a_called = false
      b_called = false

      middleware = [
        lambda do |_, _, &block|
          a_called = true
          block.call
        end
      ]
      stack = described_class.new(middleware)
      stack.run(double) { b_called = true }

      expect(a_called && b_called).to eq true
    end
  end
end

describe Discordrb::Middleware::Handler do
  subject(:handler) { described_class.new(double(:run), double) }

  describe '#matches?' do
    it 'always returns true' do
      expect(handler.matches?(double)).to eq true
    end
  end

  describe '#after_call' do
    it 'does nothing' do
      expect(handler.after_call(double)).to be_falsey
    end
  end

  describe '#call' do
    it 'runs the contained stack' do
      stack = double(:run)
      proc = proc {}
      event = double

      handler = described_class.new(stack, proc)
      expect(stack).to receive(:run).with(event) do |_event, &block|
        expect(block).to be(proc)
      end
      handler.call(event)
    end
  end
end

describe Discordrb::Middleware::HandlerMiddleware do
  describe '#call' do
    it 'yields with a matching event' do
      handler = double
      event = double
      allow(handler).to receive(:matches?).with(event).and_return(true)
      called = false

      middleware = described_class.new(handler)
      middleware.call(event, nil) do
        called = true
      end
      expect(called).to eq true
    end

    it "doesn't yield with a non-matching event" do
      handler = double
      event = double
      allow(handler).to receive(:matches?).with(event).and_return(false)
      called = false

      middleware = described_class.new(handler)
      middleware.call(event, nil) do
        called = true
      end
      expect(called).to eq false
    end
  end
end

describe Discordrb::Middleware::Stock do
  describe '.register' do
    it 'defines a new Stock class method with the provided block' do
      Discordrb::Middleware::Stock.register(:foo, :bar) do |value|
        value
      end

      Discordrb::Middleware::Stock.register(:foo, :baz) do |value|
        value
      end

      expect(Discordrb::Middleware::Stock.get(:foo, bar: 1, baz: 2)).to eq [1, 2]
    end

    it 'raises when an unknown attribute is specified' do
      Discordrb::Middleware::Stock.register(:foo, :bar) do |value|
        value
      end

      Discordrb::Middleware::Stock.register(:foo, :baz) do |value|
        value
      end

      expect { Discordrb::Middleware::Stock.get(:foo, does_not_exist: 1) }.to raise_error(ArgumentError, <<~HERE)
        Attribute :does_not_exist (given with value 1) doesn't exist for foo event handlers.
        Options are: [:bar, :baz]
      HERE
    end
  end
end

describe Discordrb::Middleware::MessageFilter do
  describe :content_end do
    it 'matches String' do
      middleware = Discordrb::Middleware::MessageFilter.new('!', :content_end)
      good_event = double(content: 'foo!')
      bad_event = double(content: 'foo')
      expect(middleware.call(good_event, double, &-> { true })).to eq true
      expect(middleware.call(bad_event, double, &-> { true })).to eq nil
    end
  end

  describe :content_end_regexp do
    it 'matches Regexp' do
      # BUG: Doesn't work without a group
      middleware = Discordrb::Middleware::MessageFilter.new(/(\!$)/, :content_end_regexp)
      good_event = double(content: 'foo!')
      bad_event = double(content: 'foo')
      expect(middleware.call(good_event, double, &-> { true })).to eq true
      expect(middleware.call(bad_event, double, &-> { true })).to eq nil
    end
  end

  describe :content_include do
    it 'matches String' do
      middleware = Discordrb::Middleware::MessageFilter.new('bar', :content_include)
      good_event = double(content: 'bar')
      bad_event = double(content: 'foo')
      expect(middleware.call(good_event, double, &-> { true })).to eq true
      expect(middleware.call(bad_event, double, &-> { true })).to eq nil
    end
  end

  describe :content_include_regexp do
    it 'matches Regexp' do
      # BUG: Doesn't work without a group
      middleware = Discordrb::Middleware::MessageFilter.new(/foo/, :content_include_regexp)
      good_event = double(content: 'foo')
      bad_event = double(content: 'bar')
      expect(middleware.call(good_event, double, &-> { true })).to eq true
      expect(middleware.call(bad_event, double, &-> { true })).to eq nil
    end
  end

  describe :author_name do
    it 'matches String by name' do
      middleware = Discordrb::Middleware::MessageFilter.new('z64', :author_name)
      good_event = double(author: double(name: 'z64'))
      bad_event = double(author: double(name: 'raelys'))
      expect(middleware.call(good_event, double, &-> { true })).to eq true
      expect(middleware.call(bad_event, double, &-> { true })).to eq nil
    end
  end

  describe :author_id do
    it 'matches Integer by id' do
      middleware = Discordrb::Middleware::MessageFilter.new(123, :author_id)
      good_event = double(author: double(id: 123))
      bad_event = double(author: double(id: 456))
      expect(middleware.call(good_event, double, &-> { true })).to eq true
      expect(middleware.call(bad_event, double, &-> { true })).to eq nil
    end
  end

  describe :author_current_bot do
    it 'matches :bot with current_bot' do
      middleware = Discordrb::Middleware::MessageFilter.new(:bot, :author_current_bot)
      good_event = double(author: double(current_bot?: true))
      bad_event = double(author: double(current_bot?: false))
      expect(middleware.call(good_event, double, &-> { true })).to eq true
      expect(middleware.call(bad_event, double, &-> { true })).to eq nil
    end
  end

  describe :content_start do
    it 'matches with String#start_with' do
      middleware = Discordrb::Middleware::MessageFilter.new('!', :content_start)
      good_event = double(content: '!foo')
      bad_event = double(content: 'foo')
      expect(middleware.call(good_event, double, &-> { true })).to eq true
      expect(middleware.call(bad_event, double, &-> { true })).to eq nil
    end
  end

  describe :content_start_regexp do
    it 'matches with a regex' do
      middleware = Discordrb::Middleware::MessageFilter.new(/\!/, :content_start_regexp)
      good_event = double(content: '!foo')
      bad_event = double(content: 'foo')
      expect(middleware.call(good_event, double, &-> { true })).to eq true
      expect(middleware.call(bad_event, double, &-> { true })).to eq nil
    end
  end

  describe :content_equal do
    it 'matches on exact content' do
      middleware = Discordrb::Middleware::MessageFilter.new('foo', :content_equal)
      good_event = double(content: 'foo')
      bad_event = double(content: 'bar')
      expect(middleware.call(good_event, double, &-> { true })).to eq true
      expect(middleware.call(bad_event, double, &-> { true })).to eq nil
    end
  end

  describe :channel_name do
    it 'matches String with channel name' do
      middleware = Discordrb::Middleware::MessageFilter.new('foo', :channel_name)
      good_event = double(channel: double(name: 'foo'))
      bad_event = double(channel: double(name: 'bar'))
      expect(middleware.call(good_event, double, &-> { true })).to eq true
      expect(middleware.call(bad_event, double, &-> { true })).to eq nil
    end
  end

  describe :channel_id do
    it 'matches Integer with channel ID' do
      middleware = Discordrb::Middleware::MessageFilter.new(123, :channel_id)
      good_event = double(channel: double(id: 123))
      bad_event = double(channel: double(id: 456))
      expect(middleware.call(good_event, double, &-> { true })).to eq true
      expect(middleware.call(bad_event, double, &-> { true })).to eq nil
    end
  end

  describe :time_after do
    it 'matches after the event timestamp' do
      middleware = Discordrb::Middleware::MessageFilter.new(1, :time_after)
      good_event = double(timestamp: 2)
      bad_event = double(timestamp: 0)
      expect(middleware.call(good_event, double, &-> { true })).to eq true
      expect(middleware.call(bad_event, double, &-> { true })).to eq nil
    end
  end

  describe :time_before do
    it 'matches before the event timestamp' do
      middleware = Discordrb::Middleware::MessageFilter.new(1, :time_before)
      good_event = double(timestamp: 0)
      bad_event = double(timestamp: 2)
      expect(middleware.call(good_event, double, &-> { true })).to eq true
      expect(middleware.call(bad_event, double, &-> { true })).to eq nil
    end
  end

  describe :private_channel do
    it 'matches in private channels' do
      middleware = Discordrb::Middleware::MessageFilter.new(true, :private_channel)
      good_event = double(channel: double(private?: true))
      bad_event = double(channel: double(private?: false))
      expect(middleware.call(good_event, double, &-> { true })).to eq true
      expect(middleware.call(bad_event, double, &-> { true })).to eq nil
    end
  end
end
