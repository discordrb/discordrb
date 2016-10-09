require 'discordrb'
require 'mock/api_mock'
using APIMock

describe APIMock do
  it 'stores the used method' do
    Discordrb::API.raw_request(:get, [])

    Discordrb::API.last_method.should == :get
  end
end
