# frozen_string_literal: true

require 'rest-client'
require 'json'
require 'time'

require 'discordrb/errors'

# List of methods representing endpoints in Discord's API
module Discordrb::API
  # The base URL of the Discord REST API.
  APIBASE = 'https://discordapp.com/api/v6'.freeze

  module_function

  # @return [String] the currently used API base URL.
  def api_base
    @api_base || APIBASE
  end

  # Sets the API base URL to something.
  def api_base=(value)
    @api_base = value
  end

  # @return [String] the bot name, previously specified using #bot_name=.
  def bot_name
    @bot_name
  end

  # Sets the bot name to something.
  def bot_name=(value)
    @bot_name = value
  end

  # Generate a user agent identifying this requester as discordrb.
  def user_agent
    # This particular string is required by the Discord devs.
    required = "DiscordBot (https://github.com/meew0/discordrb, v#{Discordrb::VERSION})"
    @bot_name ||= ''

    "rest-client/#{RestClient::VERSION} #{RUBY_ENGINE}/#{RUBY_VERSION}p#{RUBY_PATCHLEVEL} discordrb/#{Discordrb::VERSION} #{required} #{@bot_name}"
  end

  # Resets all rate limit mutexes
  def reset_mutexes
    @mutexes = {}
    @global_mutex = Mutex.new
  end

  # Wait a specified amount of time synchronised with the specified mutex.
  def sync_wait(time, mutex)
    mutex.synchronize { sleep time }
  end

  # Wait for a specified mutex to unlock and do nothing with it afterwards.
  def mutex_wait(mutex)
    mutex.lock
    mutex.unlock
  end

  # Performs a RestClient request.
  # @param type [Symbol] The type of HTTP request to use.
  # @param attributes [Array] The attributes for the request.
  def raw_request(type, attributes)
    RestClient.send(type, *attributes)
  rescue RestClient::Forbidden
    raise Discordrb::Errors::NoPermission, "The bot doesn't have the required permission to do this!"
  rescue RestClient::BadGateway
    Discordrb::LOGGER.warn('Got a 502 while sending a request! Not a big deal, retrying the request')
    retry
  end

  # Make an API request, including rate limit handling.
  def request(key, major_parameter, type, *attributes)
    # Add a custom user agent
    attributes.last[:user_agent] = user_agent if attributes.last.is_a? Hash

    # The most recent Discord rate limit requirements require the support of major parameters, where a particular route
    # and major parameter combination (*not* the HTTP method) uniquely identifies a RL bucket.
    key = [key, major_parameter].freeze

    begin
      mutex = @mutexes[key] ||= Mutex.new

      # Lock and unlock, i. e. wait for the mutex to unlock and don't do anything with it afterwards
      mutex_wait(mutex)

      # If the global mutex happens to be locked right now, wait for that as well.
      mutex_wait(@global_mutex) if @global_mutex.locked?

      response = raw_request(type, attributes)

      if response.headers[:x_ratelimit_remaining] == '0' && !mutex.locked?
        Discordrb::LOGGER.debug "RL bucket depletion detected! Date: #{response.headers[:date]} Reset: #{response.headers[:x_ratelimit_reset]}"

        now = Time.rfc2822(response.headers[:date])
        reset = Time.at(response.headers[:x_ratelimit_reset].to_i)

        delta = reset - now

        Discordrb::LOGGER.warn("Locking RL mutex (key: #{key}) for #{delta} seconds preemptively")
        sync_wait(delta, mutex)
      end
    rescue RestClient::TooManyRequests => e
      # If the 429 is from the global RL, then we have to use the global mutex instead.
      mutex = @global_mutex if e.response.headers[:x_ratelimit_global] == 'true'

      unless mutex.locked?
        response = JSON.parse(e.response)
        wait_seconds = response['retry_after'].to_i / 1000.0
        Discordrb::LOGGER.warn("Locking RL mutex (key: #{key}) for #{wait_seconds} seconds due to Discord rate limiting")

        # Wait the required time synchronized by the mutex (so other incoming requests have to wait) but only do it if
        # the mutex isn't locked already so it will only ever wait once
        sync_wait(wait_seconds, mutex)
      end

      retry
    end

    response
  end

  # Make an icon URL from server and icon IDs
  def icon_url(server_id, icon_id)
    "#{api_base}/guilds/#{server_id}/icons/#{icon_id}.jpg"
  end

  # Make an icon URL from application and icon IDs
  def app_icon_url(app_id, icon_id)
    "https://cdn.discordapp.com/app-icons/#{app_id}/#{icon_id}.jpg"
  end

  # Make a widget picture URL from server ID
  def widget_url(server_id, style = 'shield')
    "#{api_base}/guilds/#{server_id}/widget.png?style=#{style}"
  end

  # Make a splash URL from server and splash IDs
  def splash_url(server_id, splash_id)
    "https://cdn.discordapp.com/splashes/#{server_id}/#{splash_id}.jpg"
  end

  # Make an emoji icon URL from emoji ID
  def emoji_icon_url(emoji_id)
    "https://cdn.discordapp.com/emojis/#{emoji_id}.png"
  end

  # Login to the server
  def login(email, password)
    request(
      :auth_login,
      nil,
      :post,
      "#{api_base}/auth/login",
      email: email,
      password: password
    )
  end

  # Logout from the server
  def logout(token)
    request(
      :auth_logout,
      nil,
      :post,
      "#{api_base}/auth/logout",
      nil,
      Authorization: token
    )
  end

  # Create an OAuth application
  def create_oauth_application(token, name, redirect_uris)
    request(
      :oauth2_applications,
      nil,
      :post,
      "#{api_base}/oauth2/applications",
      { name: name, redirect_uris: redirect_uris }.to_json,
      Authorization: token,
      content_type: :json
    )
  end

  # Change an OAuth application's properties
  def update_oauth_application(token, name, redirect_uris, description = '', icon = nil)
    request(
      :oauth2_applications,
      nil,
      :put,
      "#{api_base}/oauth2/applications",
      { name: name, redirect_uris: redirect_uris, description: description, icon: icon }.to_json,
      Authorization: token,
      content_type: :json
    )
  end

  # Get the bot's OAuth application's information
  def oauth_application(token)
    request(
      :oauth2_applications_me,
      nil,
      :get,
      "#{api_base}/oauth2/applications/@me",
      Authorization: token
    )
  end

  # Acknowledge that a message has been received
  # The last acknowledged message will be sent in the ready packet,
  # so this is an easy way to catch up on messages
  def acknowledge_message(token, channel_id, message_id)
    request(
      :channels_cid_messages_mid_ack,
      nil, # This endpoint is unavailable for bot accounts and thus isn't subject to its rate limit requirements.
      :post,
      "#{api_base}/channels/#{channel_id}/messages/#{message_id}/ack",
      nil,
      Authorization: token
    )
  end

  # Get the gateway to be used
  def gateway(token)
    request(
      :gateway,
      nil,
      :get,
      "#{api_base}/gateway",
      Authorization: token
    )
  end

  # Validate a token (this request will fail if the token is invalid)
  def validate_token(token)
    request(
      :auth_login,
      nil,
      :post,
      "#{api_base}/auth/login",
      {}.to_json,
      Authorization: token,
      content_type: :json
    )
  end
end

Discordrb::API.reset_mutexes
