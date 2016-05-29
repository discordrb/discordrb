require 'discordrb'

describe Discordrb::Errors do
  describe 'the Code method' do
    it 'should create a class without errors' do
      Discordrb::Errors.Code(10_000)
    end

    describe 'the created class' do
      it 'should contain the correct code' do
        classy = Discordrb::Errors.Code(10_001)
        expect(classy.code).to eq(10_001)
      end

      it 'should create an instance with the correct code' do
        classy = Discordrb::Errors.Code(10_002)
        error = classy.new 'random message'
        expect(error.code).to eq(10_002)
        expect(error.message).to eq 'random message'
      end
    end
  end
end
