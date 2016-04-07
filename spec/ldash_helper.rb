require 'rest-client'
require 'json'

require 'discordrb'

module LdashClient
  LDASH_URL = 'http://127.0.0.1:6601'.freeze

  class Session
    def initialize(preset)
      Discordrb::API.api_base = LDASH_URL + '/api'
      connect(preset)
    end

    def close
    end

    private

    def connect(preset)
      RestClient.post(
        LDASH_URL + '/l-/session',
        { preset: preset }.to_json,
        content_type: :json
      )
    end
  end
end
