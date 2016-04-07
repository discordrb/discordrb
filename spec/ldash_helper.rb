require 'rest-client'
require 'json'

module LdashClient
  LDASH_URL = 'http://127.0.0.1:6601'.freeze

  class Session
    def initialize(preset)
      connect(preset)
    end

    private

    def connect(preset)
      RestClient.post(
        LDASH_URL + '/session',
        { preset: preset }.to_json,
        content_type: json
      )
    end
  end
end
