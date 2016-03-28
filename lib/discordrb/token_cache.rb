# frozen_string_literal: true

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
    # Parse the cached token from the JSON data read from the file.
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

    # @return [Hash<Symbol => String>] the data representing the token and encryption data, all encrypted and base64-encoded
    def data
      {
        verify_salt: Base64.encode64(@verify_salt),
        password_hash: Base64.encode64(@password_hash),
        encrypt_salt: Base64.encode64(@encrypt_salt),
        iv: Base64.encode64(@iv),
        encrypted_token: Base64.encode64(@encrypted_token)
      }
    end

    # Verifies this encrypted token with a given password
    # @param password [String] A plaintext password to verify
    # @see #hash_password
    # @return [true, false] whether or not the verification succeeded
    def verify_password(password)
      hash_password(password) == @password_hash
    end

    # Sets the given password as the verification password
    # @param password [String] A plaintext password to set
    # @see #hash_password
    def generate_verify_hash(password)
      @password_hash = hash_password(password)
    end

    # Generates a key from a given password using PBKDF2 with a SHA1 HMAC, 300k iterations and 32 bytes long
    # @param password [String] A password to use as the base for the key
    # @return [String] The generated key
    def obtain_key(password)
      @key = OpenSSL::PKCS5.pbkdf2_hmac_sha1(password, @encrypt_salt, 300_000, KEYLEN)
    end

    # Generates cryptographically random salts for this token
    def generate_salts
      @verify_salt = OpenSSL::Random.random_bytes(KEYLEN)
      @encrypt_salt = OpenSSL::Random.random_bytes(KEYLEN)
    end

    # Decrypts a token using a given password
    # @param password [String] The plaintext password to decrypt the token with
    # @return [String] the plaintext token
    def decrypt_token(password)
      key = obtain_key(password)
      decipher = OpenSSL::Cipher::AES256.new(:CBC)
      decipher.decrypt
      decipher.key = key
      decipher.iv = @iv
      decipher.update(@encrypted_token) + decipher.final
    end

    # Encrypts a given token with the given password, using AES256 CBC
    # @param password [String] The plaintext password to encrypt the token with
    # @param token [String] The plaintext token to encrypt
    # @return [String] the encrypted token
    def encrypt_token(password, token)
      key = obtain_key(password)
      cipher = OpenSSL::Cipher::AES256.new(:CBC)
      cipher.encrypt
      cipher.key = key
      @iv = cipher.random_iv
      @encrypted_token = cipher.update(token) + cipher.final
    end

    # Tests a token by making an API request, throws an error if not successful
    # @param token [String] A plaintext token to test
    def test_token(token)
      Discordrb::API.validate_token(token)
    end

    # Hashes a password using PBKDF2 with a SHA256 digest
    # @param password [String] The password to hash
    # @return [String] The hashed password
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
    rescue => e
      LOGGER.debug('Exception occurred while parsing token cache file:', true)
      LOGGER.log_exception(e)
      LOGGER.debug('Continuing with empty cache')
      @data = {}
    end

    # Gets a token from this token cache
    # @param email [String] The email to get the token for
    # @param password [String] The plaintext password to get the token for
    # @return [String, nil] the stored token, or nil if unsuccessful (e. g. token not cached or cached token invalid)
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
              rescue => e
                fail_token('Token cached, verified and decrypted, but rejected by Discord', email, e)
                sleep 1 # wait some time so we don't get immediately rate limited
                nil
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

    # Caches a token
    # @param email [String] The email to store this token under
    # @param password [String] The plaintext password to encrypt the token with
    # @param token [String] The plaintext token to cache
    def store_token(email, password, token)
      cached = CachedToken.new
      cached.generate_verify_hash(password)
      cached.encrypt_token(password, token)
      @data[email] = cached.data
      write_cache
    end

    # Writes the cache to a file
    def write_cache
      File.write(CACHE_PATH, @data.to_json)
    end

    private

    def fail_token(msg, email = nil, e = nil)
      LOGGER.warn("Token not retrieved from cache - #{msg}")
      LOGGER.log_exception(e) if e
      @data.delete(email) if email
      nil
    end
  end
end
