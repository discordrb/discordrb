# frozen_string_literal: true

require 'discordrb'
require 'mock/api_mock'
using APIMock

describe APIMock do
  it 'stores the used method' do
    Discordrb::API.raw_request(:get, [])

    expect(Discordrb::API.last_method).to eq :get
  end

  it 'stores the used URL' do
    url = 'https://example.com/test'
    Discordrb::API.raw_request(:get, [url])

    expect(Discordrb::API.last_url).to eq url
  end

  it 'parses the stored body using JSON' do
    body = { test: 1 }
    Discordrb::API.raw_request(:post, ['https://example.com/test', body.to_json])

    expect(Discordrb::API.last_body['test']).to eq 1
  end

  it "doesn't parse the body if there is none present" do
    Discordrb::API.raw_request(:post, ['https://example.com/test', nil])

    expect(Discordrb::API.last_body).to be_nil
  end

  it 'parses headers if there is no body' do
    Discordrb::API.raw_request(:post, ['https://example.com/test', nil, { a: 1, b: 2 }])

    expect(Discordrb::API.last_headers[:a]).to eq 1
    expect(Discordrb::API.last_headers[:b]).to eq 2
  end

  it 'parses body and headers if there is a body' do
    Discordrb::API.raw_request(:post, ['https://example.com/test', { test: 1 }.to_json, { a: 1, b: 2 }])

    expect(Discordrb::API.last_body['test']).to eq 1
    expect(Discordrb::API.last_headers[:a]).to eq 1
    expect(Discordrb::API.last_headers[:b]).to eq 2
  end
end
