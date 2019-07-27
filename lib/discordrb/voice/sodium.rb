# frozen_string_literal: true

module Discordrb::Voice
  # @!visibility private
  module Sodium
    extend FFI::Library

    ffi_lib(['sodium', 'libsodium.so.18', 'libsodium.so.23'])

    # Encryption & decryption
    attach_function(:crypto_secretbox_xsalsa20poly1305, %i[pointer pointer ulong_long pointer pointer], :int)
    attach_function(:crypto_secretbox_xsalsa20poly1305_open, %i[pointer pointer ulong_long pointer pointer], :int)

    # Constants
    attach_function(:crypto_secretbox_xsalsa20poly1305_keybytes, [], :size_t)
    attach_function(:crypto_secretbox_xsalsa20poly1305_noncebytes, [], :size_t)
    attach_function(:crypto_secretbox_xsalsa20poly1305_zerobytes, [], :size_t)
    attach_function(:crypto_secretbox_xsalsa20poly1305_boxzerobytes, [], :size_t)
  end

  # Utility class for interacting with required `xsalsa20poly1305` functions for voice transmission
  # @!visibility private
  class SecretBox
    # Exception raised when a key or nonce with invalid length is used
    class LengthError < RuntimeError
    end

    # Exception raised when encryption or decryption fails
    class CryptoError < RuntimeError
    end

    # Required key length
    KEY_LENGTH = Sodium.crypto_secretbox_xsalsa20poly1305_keybytes

    # Required nonce length
    NONCE_BYTES = Sodium.crypto_secretbox_xsalsa20poly1305_noncebytes

    # Zero byte padding for encryption
    ZERO_BYTES = Sodium.crypto_secretbox_xsalsa20poly1305_zerobytes

    # Zero byte padding for decryption
    BOX_ZERO_BYTES = Sodium.crypto_secretbox_xsalsa20poly1305_boxzerobytes

    # @param key [String] Crypto key of length {KEY_LENGTH}
    def initialize(key)
      raise(LengthError, 'Key length') if key.bytesize != KEY_LENGTH

      @key = key
    end

    # Encrypts a message using this box's key
    # @param nonce [String] encryption nonce for this message
    # @param message [String] message to be encrypted
    def box(nonce, message)
      raise(LengthError, 'Nonce length') if nonce.bytesize != NONCE_BYTES

      message_padded = prepend_zeroes(ZERO_BYTES, message)
      buffer = zero_string(message_padded.bytesize)

      success = Sodium.crypto_secretbox_xsalsa20poly1305(buffer, message_padded, message_padded.bytesize, nonce, @key)
      raise(CryptoError, "Encryption failed (#{success})") unless success.zero?

      remove_zeroes(BOX_ZERO_BYTES, buffer)
    end

    # Decrypts the given ciphertext using this box's key
    # @param nonce [String] encryption nonce for this ciphertext
    # @param ciphertext [String] ciphertext to decrypt
    def open(nonce, ciphertext)
      raise(LengthError, 'Nonce length') if nonce.bytesize != NONCE_BYTES

      ct_padded = prepend_zeroes(BOX_ZERO_BYTES, ciphertext)
      buffer = zero_string(ct_padded.bytesize)

      success = Sodium.crypto_secretbox_xsalsa20poly1305_open(buffer, ct_padded, ct_padded.bytesize, nonce, @key)
      raise(CryptoError, "Decryption failed (#{success})") unless success.zero?

      remove_zeroes(ZERO_BYTES, buffer)
    end

    private

    def zero_string(size)
      str = "\0" * size
      str.force_encoding('ASCII-8BIT') if str.respond_to?(:force_encoding)
    end

    def prepend_zeroes(size, string)
      zero_string(size) + string
    end

    def remove_zeroes(size, string)
      string.slice!(size, string.bytesize - size)
    end
  end
end
