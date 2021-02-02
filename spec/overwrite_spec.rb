# frozen_string_literal: true

require 'discordrb'

describe Discordrb::Overwrite do
  describe '#initialize' do
    context 'when object is an Integer' do
      let(:id) { instance_double(Integer) }

      it 'accepts the API value for `type`' do
        overwrite = described_class.new(id, type: 0, allow: 0, deny: 0)

        expect(overwrite.type).to eq Discordrb::Overwrite::TYPES.key(0)
      end

      it 'accepts a short name value for `type`' do
        overwrite = described_class.new(id, type: :role, allow: 0, deny: 0)

        expect(overwrite.type).to eq :role
      end

      it 'accepts a string as a value for `type`' do
        overwrite = described_class.new(id, type: 'role', allow: 0, deny: 0)

        expect(overwrite.type).to eq :role
      end
    end

    context 'when object is a User type' do
      let(:user_types) { [Discordrb::User, Discordrb::Member, Discordrb::Recipient, Discordrb::Profile] }
      let(:users) do
        user_types.collect { |k| [k, instance_double(k)] }.to_h
      end

      before do
        users.each do |user_type, dbl|
          allow(user_type).to receive(:===).with(anything).and_return(false)
          allow(user_type).to receive(:===).with(dbl).and_return(true)
        end
      end

      it 'infers type from a User object' do
        users.each do |_user_type, user|
          expect(described_class.new(user).type).to eq :member
        end
      end
    end

    context 'when object is a Role' do
      let(:role) { instance_double(Discordrb::Role) }

      it 'infers type from a Role object' do
        allow(Discordrb::Role).to receive(:===).with(anything).and_return(false)
        allow(Discordrb::Role).to receive(:===).with(role).and_return(true)

        expect(described_class.new(role).type).to eq :role
      end
    end
  end

  describe '#to_hash' do
    let(:id) { instance_double(Integer) }
    let(:allow_perm) { instance_double(Discordrb::Permissions, bits: allow_bits) }
    let(:allow_bits) { instance_double(Integer) }
    let(:deny_perm) { instance_double(Discordrb::Permissions, bits: deny_bits) }
    let(:deny_bits) { instance_double(Integer) }

    before do
      allow(allow_perm).to receive(:is_a?).with(Discordrb::Permissions).and_return(true)
      allow(deny_perm).to receive(:is_a?).with(Discordrb::Permissions).and_return(true)
    end

    it 'creates a hash from the relevant values' do
      overwrite = described_class.new(id, type: :member, allow: allow_perm, deny: deny_perm)
      expect(overwrite.to_hash).to eq({
                                        id: id,
                                        type: Discordrb::Overwrite::TYPES[:member],
                                        allow: allow_bits,
                                        deny: deny_bits
                                      })
    end
  end

  describe '.from_hash' do
    let(:id) { instance_double(Integer) }
    let(:type) { Discordrb::Overwrite::TYPES[:role] }

    before do
      allow(id).to receive(:to_i).and_return(id)
    end

    it 'converts a hash to an Overwrite' do
      overwrite = described_class.from_hash({
                                              'id' => id, 'type' => type, 'allow' => 0, 'deny': 0
                                            })

      expect(overwrite).to eq described_class.new(id, type: :role, allow: 0, deny: 0)
    end
  end

  describe '.from_other' do
    let(:original) { described_class.new(12_345, type: :role, allow: 100, deny: 100) }

    it 'creates a new object from another Overwrite' do
      copy = described_class.from_other(original)

      expect(copy).to eq original
    end

    it 'creates new permission objects' do
      copy = described_class.from_other(original)

      expect(copy.allow).not_to be original.allow
      expect(copy.deny).not_to be original.deny
    end
  end
end
