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
  shared_examples 'middleware attributes' do |middleware, examples|
    matching, non_matching = examples

    describe middleware.inspect do
      it "matches #{matching}" do
        event = nested_double(nil, matching)
        expect(middleware.call(event, double, &-> { true })).to eq true
      end

      it "doesn't match #{non_matching}" do
        event = nested_double(nil, non_matching)
        expect(middleware.call(event, double, &-> { true })).to eq nil
      end
    end
  end

  include_examples(
    'middleware attributes',
    Discordrb::Middleware::MessageFilter.new('foo', :content_equal),
    [{ content: 'foo' }, { content: 'bar' }]
  )

  include_examples(
    'middleware attributes',
    Discordrb::Middleware::MessageFilter.new('foo', :content_start),
    [{ content: 'foo bar' }, { content: 'baz bar' }]
  )

  include_examples(
    'middleware attributes',
    Discordrb::Middleware::MessageFilter.new(/foo/, :content_start_regexp),
    [{ content: 'foo bar' }, { content: 'baz bar' }]
  )

  include_examples(
    'middleware attributes',
    Discordrb::Middleware::MessageFilter.new('!', :content_end),
    [{ content: 'foo!' }, { content: 'foo' }]
  )

  include_examples(
    'middleware attributes',
    Discordrb::Middleware::MessageFilter.new(/(\!$)/, :content_end_regexp),
    [{ content: 'foo!' }, { content: 'foo' }]
  )

  include_examples(
    'middleware attributes',
    Discordrb::Middleware::MessageFilter.new('bar', :content_include),
    [{ content: 'foo bar baz' }, { content: 'foo baz' }]
  )

  include_examples(
    'middleware attributes',
    Discordrb::Middleware::MessageFilter.new(/bar/, :content_include_regexp),
    [{ content: 'foo bar baz' }, { content: 'foo baz' }]
  )

  include_examples(
    'middleware attributes',
    Discordrb::Middleware::MessageFilter.new('z64', :author_name),
    [{ author: { name: 'z64' } }, { author: { name: 'raelys' } }]
  )

  include_examples(
    'middleware attributes',
    Discordrb::Middleware::MessageFilter.new(1, :author_id),
    [{ author: { id: 1 } }, { author: { id: 2 } }]
  )

  include_examples(
    'middleware attributes',
    Discordrb::Middleware::MessageFilter.new(:bot, :author_current_bot),
    [{ author: { current_bot?: true } }, { author: { current_bot?: false } }]
  )

  include_examples(
    'middleware attributes',
    Discordrb::Middleware::MessageFilter.new(1, :channel_id),
    [{ channel: { id: 1 } }, { channel: { id: 2 } }]
  )

  include_examples(
    'middleware attributes',
    Discordrb::Middleware::MessageFilter.new('foo', :channel_name),
    [{ channel: { name: 'foo' } }, { channel: { name: 'bar' } }]
  )

  include_examples(
    'middleware attributes',
    Discordrb::Middleware::MessageFilter.new(1, :time_after),
    [{ timestamp: 2 }, { timestamp: 0 }]
  )

  include_examples(
    'middleware attributes',
    Discordrb::Middleware::MessageFilter.new(1, :time_before),
    [{ timestamp: 0 }, { timestamp: 2 }]
  )

  include_examples(
    'middleware attributes',
    Discordrb::Middleware::MessageFilter.new(true, :private_channel),
    [{ channel: { private?: true } }, { channel: { private?: false } }]
  )

  it 'inverts condition when negated' do
    middleware = Discordrb::Middleware::MessageFilter.new(not!(double('value')), :content_equal)
    allow(middleware).to receive(:content_equal).and_return(false)
    result = middleware.call(double('event'), double('state'), &-> { true })
    expect(result).to eq true
  end
end
