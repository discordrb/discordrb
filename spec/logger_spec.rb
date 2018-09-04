# frozen_string_literal: true

require 'discordrb'

describe Discordrb::Logger do
  it 'should log messages' do
    stream = spy
    logger = Discordrb::Logger.new(false, [stream])

    logger.error('Testing')

    expect(stream).to have_received(:puts).with(something_including('Testing'))
  end

  it 'should respect the log mode' do
    stream = spy
    logger = Discordrb::Logger.new(false, [stream])
    logger.mode = :silent

    logger.error('Testing')

    expect(stream).to_not have_received(:puts)
  end

  context 'fancy mode' do
    it 'should log messages' do
      stream = spy
      logger = Discordrb::Logger.new(true, [stream])

      logger.error('Testing')

      expect(stream).to have_received(:puts).with(something_including('Testing'))
    end
  end

  context 'redacted token' do
    it 'should redact the token from messages' do
      stream = spy
      logger = Discordrb::Logger.new(true, [stream])
      logger.token = 'asdfg'

      logger.error('this message contains a token that should be redacted: asdfg')

      expect(stream).to have_received(:puts).with(something_not_including('asdfg'))
    end
  end
end
