require 'base64'
require 'json'
require 'openssl'

# Discordrb
module Discordrb
  # Amount of bytes the key should be long (32 bytes = 256 bits -> AES256)
  KEYLEN = 32

  # Represents a cached token with encryption data
  class CachedToken
    def initialize(data = nil)
      if data
        @verify_salt = Base64.decode64(data['verify_salt'])
        @password_hash = Base64.decode64(data['password_hash'])
        @encrypt_salt = Base64.decode64(data['encrypt_salt'])
        @iv = Base64.decode64(data['iv'])
        @encrypted_token = Base64.decode64(data['encrypted_token'])
      else
        generate_salts
      end
    end

    def data
      {
        verify_salt: Base64.encode64(@verify_salt),
        password_hash: Base64.encode64(@password_hash),
        encrypt_salt: Base64.encode64(@encrypt_salt),
        iv: Base64.encode64(@iv),
        encrypted_token: Base64.encode64(@encrypted_token)
      }
    end

    def verify_password(password)
      hash_password(password) == @password_hash
    end

    def generate_verify_hash(password)
      @password_hash = hash_password(password)
    end

    def obtain_key(password)
      @key = OpenSSL::PKCS5.pbkdf2_hmac_sha1(password, @encrypt_salt, 20_000, KEYLEN)
    end

    def generate_salts
      @verify_salt = OpenSSL::Random.random_bytes(KEYLEN)
      @encrypt_salt = OpenSSL::Random.random_bytes(KEYLEN)
    end

    def decrypt_token(password)
      key = obtain_key(password)
      decipher = OpenSSL::Cipher::AES256.new(:CBC)
      decipher.decrypt
      decipher.key = key
      decipher.iv = @iv
      @token = decipher.update(@encrypted_token) + decipher.final
      @token
    end

    def encrypt_token(password)
      key = obtain_key(password)
      cipher = OpenSSL::Cipher::AES256.new(:CBC)
      cipher.encrypt
      cipher.key = key
      @iv = cipher.random_iv
      @encrypted_token = cipher.update(@token) + cipher.final
      @encrypted_token
    end

    private

    def hash_password(password)
      digest = OpenSSL::Digest::SHA256.new
      OpenSSL::PKCS5.pbkdf2_hmac(password, @verify_salt, 20_000, digest.digest_length, digest)
    end
  end
end
