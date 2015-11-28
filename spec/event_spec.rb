require 'discordrb'

describe Discordrb::Events do
  describe Discordrb::Events::Negated do
    it 'should initialize without errors' do
      Discordrb::Events::Negated.new(:test)
    end

    it 'should contain the passed object' do
      negated = Discordrb::Events::Negated.new(:test)
      negated.object.should == :test
    end
  end

  describe 'not!' do
    it 'should return a Negated object' do
      not!(:test).should be_a(Discordrb::Events::Negated)
    end

    it 'should contain the correct value' do
      not!(:test).object.should == :test
    end
  end

  describe 'matches_all' do
    it 'should return true for a nil attribute' do
      Discordrb::Events.matches_all(nil, nil).should == true
    end

    it 'should be truthy if the block is truthy' do
      Discordrb::Events.matches_all(:a, :e) { true }.should be_truthy
      Discordrb::Events.matches_all(:a, :e) { 1 }.should be_truthy
      Discordrb::Events.matches_all(:a, :e) { 0 }.should be_truthy
      Discordrb::Events.matches_all(:a, :e) { 'string' }.should be_truthy
      Discordrb::Events.matches_all(:a, :e) { false }.should_not be_truthy
    end

    it 'should be falsey if the block is falsey' do
      Discordrb::Events.matches_all(:a, :e) { nil }.should be_falsy
      Discordrb::Events.matches_all(:a, :e) { false }.should be_falsy
      Discordrb::Events.matches_all(:a, :e) { 0 }.should_not be_falsy
    end

    it 'should correctly pass the arguments given' do
      Discordrb::Events.matches_all(:one, :two) do |a, e|
        a.should eq(:one)
        e.should eq(:two)
      end
    end

    it 'should correctly compare arguments for comparison blocks' do
      Discordrb::Events.matches_all(1, 1) { |a, e| a == e }.should be_truthy
      Discordrb::Events.matches_all(1, 0) { |a, e| a == e }.should be_falsy
      Discordrb::Events.matches_all(0, 1) { |a, e| a == e }.should be_falsy
      Discordrb::Events.matches_all(0, 0) { |a, e| a == e }.should be_truthy
      Discordrb::Events.matches_all(1, 1) { |a, e| a != e }.should be_falsy
      Discordrb::Events.matches_all(1, 0) { |a, e| a != e }.should be_truthy
      Discordrb::Events.matches_all(0, 1) { |a, e| a != e }.should be_truthy
      Discordrb::Events.matches_all(0, 0) { |a, e| a != e }.should be_falsy
    end

    it 'should return the opposite results for negated arguments' do
      Discordrb::Events.matches_all(not!(:a), :e) { true }.should be_falsy
      Discordrb::Events.matches_all(not!(:a), :e) { 1 }.should be_falsy
      Discordrb::Events.matches_all(not!(:a), :e) { 0 }.should be_falsy
      Discordrb::Events.matches_all(not!(:a), :e) { 'string' }.should be_falsy
      Discordrb::Events.matches_all(not!(:a), :e) { false }.should_not be_falsy
      Discordrb::Events.matches_all(not!(:a), :e) { nil }.should be_truthy
      Discordrb::Events.matches_all(not!(:a), :e) { false }.should be_truthy
      Discordrb::Events.matches_all(not!(:a), :e) { 0 }.should_not be_truthy
      Discordrb::Events.matches_all(not!(1), 1) { |a, e| a == e }.should be_falsy
      Discordrb::Events.matches_all(not!(1), 0) { |a, e| a == e }.should be_truthy
      Discordrb::Events.matches_all(not!(0), 1) { |a, e| a == e }.should be_truthy
      Discordrb::Events.matches_all(not!(0), 0) { |a, e| a == e }.should be_falsy
      Discordrb::Events.matches_all(not!(1), 1) { |a, e| a != e }.should be_truthy
      Discordrb::Events.matches_all(not!(1), 0) { |a, e| a != e }.should be_falsy
      Discordrb::Events.matches_all(not!(0), 1) { |a, e| a != e }.should be_falsy
      Discordrb::Events.matches_all(not!(0), 0) { |a, e| a != e }.should be_truthy
    end

    it 'should find one correct element inside arrays' do
      Discordrb::Events.matches_all([1, 2, 3], 1) { |a, e| a == e }.should be_truthy
      Discordrb::Events.matches_all([1, 2, 3], 2) { |a, e| a == e }.should be_truthy
      Discordrb::Events.matches_all([1, 2, 3], 3) { |a, e| a == e }.should be_truthy
      Discordrb::Events.matches_all([1, 2, 3], 4) { |a, e| a != e }.should be_truthy
    end

    it 'should return false when nothing matches inside arrays' do
      Discordrb::Events.matches_all([1, 2, 3], 4) { |a, e| a == e }.should be_falsy
    end

    it 'should return the respective opposite results for negated arrays' do
      Discordrb::Events.matches_all(not!([1, 2, 3]), 1) { |a, e| a == e }.should be_falsy
      Discordrb::Events.matches_all(not!([1, 2, 3]), 2) { |a, e| a == e }.should be_falsy
      Discordrb::Events.matches_all(not!([1, 2, 3]), 3) { |a, e| a == e }.should be_falsy
      Discordrb::Events.matches_all(not!([1, 2, 3]), 4) { |a, e| a != e }.should be_falsy
      Discordrb::Events.matches_all(not!([1, 2, 3]), 4) { |a, e| a == e }.should be_truthy
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
        Discordrb::Events::TrueEventHandler.new({}, nil).matches?(nil).should == true
      end

      it 'should always call the block given' do
        count = 0
        Discordrb::Events::TrueEventHandler.new({}, proc { count += 1 }).match(nil)
        Discordrb::Events::TrueEventHandler.new({}, proc { count += 2 }).match(1)
        Discordrb::Events::TrueEventHandler.new({}, proc do |e|
          e.should eq(1)
          count += 4
        end).match(1)
        Discordrb::Events::TrueEventHandler.new({ a: :b }, proc { count += 8 }).match(1)
        Discordrb::Events::TrueEventHandler.new(nil, proc { count += 16 }).match(1)
      end
    end
  end
end
