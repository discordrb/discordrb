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
end
