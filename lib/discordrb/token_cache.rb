require 'base64'
require 'json'
require 'openssl'
require 'discordrb/api'

# Discordrb
module Discordrb
  # Amount of bytes the token encryption key should be long (32 bytes = 256 bits -> AES256)
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
      @key = OpenSSL::PKCS5.pbkdf2_hmac_sha1(password, @encrypt_salt, 300_000, KEYLEN)
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
      decipher.update(@encrypted_token) + decipher.final
    end

    def encrypt_token(password, token)
      key = obtain_key(password)
      cipher = OpenSSL::Cipher::AES256.new(:CBC)
      cipher.encrypt
      cipher.key = key
      @iv = cipher.random_iv
      @encrypted_token = cipher.update(token) + cipher.final
    end

    def test_token(token)
      Discordrb::API.gateway(token)
    end

    private

    def hash_password(password)
      digest = OpenSSL::Digest::SHA256.new
      OpenSSL::PKCS5.pbkdf2_hmac(password, @verify_salt, 300_000, digest.digest_length, digest)
    end
  end

  # Path where the token cache file will be stored
  CACHE_PATH = Dir.home + '/.discordrb_token_cache.json'

  # Represents a token file
  class TokenCache
    def initialize
      if File.file? CACHE_PATH
        @data = JSON.parse(File.read(CACHE_PATH))
      else
        LOGGER.debug("Cache file #{CACHE_PATH} not found. Using empty cache")
        @data = {}
      end
    end

    def token(email, password)
      if @data[email]
        begin
          cached = CachedToken.new(@data[email])
          if cached.verify_password(password)
            token = cached.decrypt_token(password)
            if token
              begin
                cached.test_token(token)
                token
              rescue => e; fail_token('Token cached, verified and decrypted, but rejected by Discord', email, e)
              end
            else; fail_token('Token cached and verified, but decryption failed', email)
            end
          else; fail_token('Token verification failed', email)
          end
        rescue => e; fail_token('Token cached but invalid', email, e)
        end
      else; fail_token('Token not cached at all')
      end
    end

    def store_token(email, password, token)
      cached = CachedToken.new
      cached.generate_verify_hash(password)
      cached.encrypt_token(password, token)
      @data[email] = cached.data
      write_cache
    end

    def write_cache
      File.write(CACHE_PATH, @data.to_json)
    end

    private

    def fail_token(msg, email = nil, e = nil)
      LOGGER.debug("Token not retrieved from cache - #{msg}")
      LOGGER.log_exception(e, false) if e
      @data.delete(email) if email
      nil
    end
  end
end
