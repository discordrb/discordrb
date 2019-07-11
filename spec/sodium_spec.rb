# frozen_string_literal: true

require 'discordrb/voice/sodium'

describe Discordrb::Voice::SecretBox do
  def rand_bytes(size)
    bytes = Array.new(size) { rand(256) }
    bytes.pack('C*')
  end

  it 'encrypts round trip' do
    key = rand_bytes(Discordrb::Voice::SecretBox::KEY_LENGTH)
    nonce = rand_bytes(Discordrb::Voice::SecretBox::NONCE_BYTES)
    message = rand_bytes(20)

    secret_box = Discordrb::Voice::SecretBox.new(key)
    ct = secret_box.box(nonce, message)
    pt = secret_box.open(nonce, ct)
    expect(pt).to eq message
  end

  it 'raises on invalid key length' do
    key = rand_bytes(Discordrb::Voice::SecretBox::KEY_LENGTH - 1)
    expect { Discordrb::Voice::SecretBox.new(key) }.to raise_error(Discordrb::Voice::SecretBox::LengthError)
  end

  describe '#box' do
    it 'raises on invalid nonce length' do
      key = rand_bytes(Discordrb::Voice::SecretBox::KEY_LENGTH)
      nonce = rand_bytes(Discordrb::Voice::SecretBox::NONCE_BYTES - 1)
      expect { Discordrb::Voice::SecretBox.new(key).box(nonce, '') }.to raise_error(Discordrb::Voice::SecretBox::LengthError)
    end
  end

  describe '#open' do
    it 'raises on invalid nonce length' do
      key = rand_bytes(Discordrb::Voice::SecretBox::KEY_LENGTH)
      nonce = rand_bytes(Discordrb::Voice::SecretBox::NONCE_BYTES - 1)
      expect { Discordrb::Voice::SecretBox.new(key).open(nonce, '') }.to raise_error(Discordrb::Voice::SecretBox::LengthError)
    end
  end
end
