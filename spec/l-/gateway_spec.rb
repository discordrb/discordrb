require 'discordrb'

describe Discordrb::Bot do
  it 'should login with user and password' do
    session = LdashClient::Session.new(:default)
    bot = Discordrb::Bot.new(email: 'abc@test.com', password: 'l- is awesome!', token_cache: false)

    bot.token.should_not be_nil

    session.close
  end
end
