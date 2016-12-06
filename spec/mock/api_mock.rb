# Mock for Discordrb::API that allows setting arbitrary results and checking previous requests
require 'json'

module APIMock
  refine Discordrb::API.singleton_class do
    attr_reader :last_method
    attr_reader :last_url
    attr_reader :last_body
    attr_reader :last_headers

    attr_writer :next_response

    def raw_request(type, attributes)
      @last_method = type
      @last_url = attributes.first
      @last_body = attributes[1].is_a?(Hash) ? nil : JSON.parse(attributes[1]) if attributes[1]
      @last_headers = attributes.last

      @next_response
    end
  end
end
