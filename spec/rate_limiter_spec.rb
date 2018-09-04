# frozen_string_literal: true

require 'discordrb'

# alias so I don't have to type it out every time...
BUCKET = Discordrb::Commands::Bucket
RATELIMITER = Discordrb::Commands::RateLimiter

describe Discordrb::Commands::Bucket do
  describe 'rate_limited?' do
    it 'should not rate limit one request' do
      expect(BUCKET.new(1, 5, 2).rate_limited?(:a)).to be_falsy
      expect(BUCKET.new(nil, nil, 2).rate_limited?(:a)).to be_falsy
      expect(BUCKET.new(1, 5, nil).rate_limited?(:a)).to be_falsy
      expect(BUCKET.new(0, 1, nil).rate_limited?(:a)).to be_falsy
      expect(BUCKET.new(0, 1_000_000_000, 500_000_000).rate_limited?(:a)).to be_falsy
    end

    it 'should fail to initialize with invalid arguments' do
      expect { BUCKET.new(0, nil, 0) }.to raise_error(ArgumentError)
    end

    it 'should fail to rate limit something invalid' do
      expect { BUCKET.new(1, 5, 2).rate_limited?("can't RL a string!") }.to raise_error(ArgumentError)
    end

    it 'should rate limit one request over the limit' do
      b = BUCKET.new(1, 5, nil)
      expect(b.rate_limited?(:a)).to be_falsy
      expect(b.rate_limited?(:a)).to be_truthy
    end

    it 'should rate limit multiple requests that are over the limit' do
      b = BUCKET.new(3, 5, nil)
      expect(b.rate_limited?(:a)).to be_falsy
      expect(b.rate_limited?(:a)).to be_falsy
      expect(b.rate_limited?(:a)).to be_falsy
      expect(b.rate_limited?(:a)).to be_truthy
    end

    it 'should allow to be passed a custom increment' do
      b = BUCKET.new(5, 5, nil)
      expect(b.rate_limited?(:a, increment: 2)).to be_falsy
      expect(b.rate_limited?(:a, increment: 2)).to be_falsy
      expect(b.rate_limited?(:a, increment: 2)).to be_truthy
    end

    it 'should not rate limit after the limit ran out' do
      b = BUCKET.new(2, 5, nil)
      expect(b.rate_limited?(:a)).to be_falsy
      expect(b.rate_limited?(:a)).to be_falsy
      expect(b.rate_limited?(:a)).to be_truthy
      expect(b.rate_limited?(:a, Time.now + 4)).to be_truthy
      expect(b.rate_limited?(:a, Time.now + 5)).to be_falsy
    end

    it 'should reset the limit after it ran out' do
      b = BUCKET.new(2, 5, nil)
      expect(b.rate_limited?(:a)).to be_falsy
      expect(b.rate_limited?(:a)).to be_falsy
      expect(b.rate_limited?(:a)).to be_truthy
      expect(b.rate_limited?(:a, Time.now + 5)).to be_falsy
      expect(b.rate_limited?(:a, Time.now + 5.01)).to be_falsy
      expect(b.rate_limited?(:a, Time.now + 5.02)).to be_truthy
    end

    it 'should rate limit based on delay' do
      b = BUCKET.new(nil, nil, 2)
      expect(b.rate_limited?(:a)).to be_falsy
      expect(b.rate_limited?(:a)).to be_truthy
    end

    it 'should not rate limit after the delay ran out' do
      b = BUCKET.new(nil, nil, 2)
      expect(b.rate_limited?(:a)).to be_falsy
      expect(b.rate_limited?(:a)).to be_truthy
      expect(b.rate_limited?(:a, Time.now + 2)).to be_falsy
      expect(b.rate_limited?(:a, Time.now + 2)).to be_truthy
      expect(b.rate_limited?(:a, Time.now + 4)).to be_falsy
      expect(b.rate_limited?(:a, Time.now + 4)).to be_truthy
    end

    it 'should rate limit based on both limit and delay' do
      b = BUCKET.new(2, 5, 2)
      expect(b.rate_limited?(:a)).to be_falsy
      expect(b.rate_limited?(:a)).to be_truthy
      expect(b.rate_limited?(:a, Time.now + 2)).to be_falsy
      expect(b.rate_limited?(:a, Time.now + 2)).to be_truthy
      expect(b.rate_limited?(:a, Time.now + 4)).to be_truthy
      expect(b.rate_limited?(:a, Time.now + 5)).to be_falsy
      expect(b.rate_limited?(:a, Time.now + 6)).to be_truthy

      b = BUCKET.new(2, 5, 2)
      expect(b.rate_limited?(:a)).to be_falsy
      expect(b.rate_limited?(:a)).to be_truthy
      expect(b.rate_limited?(:a, Time.now + 4)).to be_falsy
      expect(b.rate_limited?(:a, Time.now + 4)).to be_truthy
      expect(b.rate_limited?(:a, Time.now + 5)).to be_truthy
    end

    it 'should return correct times' do
      start_time = Time.now
      b = BUCKET.new(2, 5, 2)
      expect(b.rate_limited?(:a, start_time)).to be_falsy
      expect(b.rate_limited?(:a, start_time).round(2)).to eq(2)
      expect(b.rate_limited?(:a, start_time + 1).round(2)).to eq(1)
      expect(b.rate_limited?(:a, start_time + 2.01)).to be_falsy
      expect(b.rate_limited?(:a, start_time + 2).round(2)).to eq(3)
    end
  end
end
