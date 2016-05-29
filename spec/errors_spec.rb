require 'discordrb'

describe Discordrb::Errors do
  describe 'the Code method' do
    it 'should create a class without errors' do
      Discordrb::Errors.Code(10_000)
    end
  end
end
