require 'discordrb'

module Discordrb
  describe Permissions do
    subject { Permissions.new }

    describe Permissions::Flags do
      it 'creates a setter for each flag' do
        responds_to_methods = Permissions::Flags.map do |_, flag|
          subject.respond_to?(:"can_#{flag}=")
        end

        expect(responds_to_methods.all?).to eq true
      end

      it 'calls #write on its writer' do
        writer = double
        expect(writer).to receive(:write)

        Permissions.new(0, writer).can_read_messages = true
      end
    end

    context 'with Flags stubbed' do
      before do
        stub_const('Discordrb::Permissions::Flags', 0 => :foo, 1 => :bar)
      end

      describe '#init_vars' do
        it 'sets an attribute for each flag' do
          expect(
            [
              subject.instance_variable_get('@foo'),
              subject.instance_variable_get('@bar')
            ]
          ).to eq [false, false]
        end
      end

      describe '.bits' do
        it 'returns the correct packed bits from an array of symbols' do
          expect(Permissions.bits(%i[foo bar])).to eq 3
        end
      end

      describe '#bits=' do
        it 'updates the cached value' do
          allow(subject).to receive(:init_vars)
          subject.bits = 1
          expect(subject.bits).to eq(1)
        end

        it 'calls #init_vars' do
          expect(subject).to receive(:init_vars)
          subject.bits = 0
        end
      end

      describe '#initialize' do
        it 'initializes with 0 bits' do
          expect(subject.bits).to eq 0
        end

        it 'can initialize with an array of symbols' do
          instance = Permissions.new %i[foo bar]
          expect(instance.bits).to eq 3
        end

        it 'calls #init_vars' do
          expect_any_instance_of(Permissions).to receive(:init_vars)
          subject
        end
      end
    end
  end
end
