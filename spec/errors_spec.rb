require 'discordrb'

describe Discordrb::Errors do
  describe 'the Code method' do
    it 'should create a class without errors' do
      Discordrb::Errors.Code(10_000)
    end

    describe 'the created class' do
      it 'should contain the correct code' do
        classy = Discordrb::Errors.Code(10_001)
        classy.code should eq(10_001)
      end

      it 'should create an instance with the correct code' do
        classy = Discordrb::Errors.Code(10_002)
        error = classy.new 'random message'
        error.code should eq(10_002)
        error.message should eq 'random message'
      end

      it 'should be able to be inherited with the correct code' do
        class SomeErrorClass < Discordrb::Errors.Code(10_003); end
        SomeErrorClass.code should eq(10_003)
        error = SomeErrorClass.new 'random message 2'
        error.code should eq(10_003)
        error.message should eq 'random message 2'
      end
    end
  end
end
