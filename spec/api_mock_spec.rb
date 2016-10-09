require 'discordrb'
require 'mock/api_mock'
using APIMock

describe APIMock do
  it 'stores the used method' do
    Discordrb::API.raw_request(:get, [])

    Discordrb::API.last_method.should == :get
  end

  it 'stores the used URL' do
    url = 'https://example.com/test'
    Discordrb::API.raw_request(:get, [url])

    Discordrb::API.last_url.should == url
  end

  it 'parses the stored body using JSON' do
    body = { test: 1 }
    Discordrb::API.raw_request(:post, ['https://example.com/test', body.to_json])

    Discordrb::API.last_body['test'].should == 1
  end

  it "doesn't parse the body if there is none present" do
    Discordrb::API.raw_request(:post, ['https://example.com/test', nil])

    Discordrb::API.last_body.should be_nil
  end
end
