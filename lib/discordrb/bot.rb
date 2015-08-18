require 'rest-client'

require 'discordrb/endpoints/endpoints'

require 'discordrb/exceptions'

module Discordrb
  class Bot
    def initialize(email, password)
      @email = email
      @password = password

      # Login
      login_response = RestClient.post Discordrb::Endpoints::LOGIN, :email => email, :password => password
      raise HTTPStatusException.new(response.code) if response.code >= 400

      # Parse response
      login_response_object = JSON.parse(login_response)
      raise InvalidAuthenticationException unless login_response_object[token]

      @token = login_response_object[token]
    end
  end
end
