# frozen_string_literal: true

require 'rest-client'
require 'json'
require 'time'

require 'discordrb/errors'

# List of methods representing endpoints in Discord's API
module Discordrb::API
  # The base URL of the Discord REST API.
  APIBASE = 'https://discord.com/api/v6'

  # The URL of Discord's CDN
  CDN_URL = 'https://cdn.discordapp.com'

  module_function

  # @return [String] the currently used API base URL.
  def api_base
    @api_base || APIBASE
  end

  # Sets the API base URL to something.
  def api_base=(value)
    @api_base = value
  end

  # @return [String] the currently used CDN url
  def cdn_url
    @cdn_url || CDN_URL
  end

  # @return [String] the bot name, previously specified using {.bot_name=}.
  def bot_name
    @bot_name
  end

  # Sets the bot name to something. Used in {.user_agent}. For the bot's username, see {Profile#username=}.
  def bot_name=(value)
    @bot_name = value
  end

  # Changes the rate limit tracing behaviour. If rate limit tracing is on, a full backtrace will be logged on every RL
  # hit.
  # @param value [true, false] whether or not to enable rate limit tracing
  def trace=(value)
    @trace = value
  end

  # Generate a user agent identifying this requester as discordrb.
  def user_agent
    # This particular string is required by the Discord devs.
    required = "DiscordBot (https://github.com/shardlab/discordrb, v#{Discordrb::VERSION})"
    @bot_name ||= ''

    "#{required} rest-client/#{RestClient::VERSION} #{RUBY_ENGINE}/#{RUBY_VERSION}p#{RUBY_PATCHLEVEL} discordrb/#{Discordrb::VERSION} #{@bot_name}"
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
  rescue RestClient::Forbidden => e
    # HACK: for #request, dynamically inject restclient's response into NoPermission - this allows us to rate limit
    noprm = Discordrb::Errors::NoPermission.new
    noprm.define_singleton_method(:_rc_response) { e.response }
    raise noprm, "The bot doesn't have the required permission to do this!"
  rescue RestClient::BadGateway
    Discordrb::LOGGER.warn('Got a 502 while sending a request! Not a big deal, retrying the request')
    retry
  end

  # Make an API request, including rate limit handling.
  def request(key, major_parameter, type, *attributes)
    # Add a custom user agent
    attributes.last[:user_agent] = user_agent if attributes.last.is_a? Hash

    # Specify RateLimit precision
    attributes.last[:x_ratelimit_precision] = 'millisecond' if attributes.last.is_a?(Hash)

    # The most recent Discord rate limit requirements require the support of major parameters, where a particular route
    # and major parameter combination (*not* the HTTP method) uniquely identifies a RL bucket.
    key = [key, major_parameter].freeze

    begin
      mutex = @mutexes[key] ||= Mutex.new

      # Lock and unlock, i.e. wait for the mutex to unlock and don't do anything with it afterwards
      mutex_wait(mutex)

      # If the global mutex happens to be locked right now, wait for that as well.
      mutex_wait(@global_mutex) if @global_mutex.locked?

      response = nil
      begin
        response = raw_request(type, attributes)
      rescue RestClient::Exception => e
        response = e.response
        raise e
      rescue Discordrb::Errors::NoPermission => e
        if e.respond_to?(:_rc_response)
          response = e._rc_response
        else
          Discordrb::LOGGER.warn("NoPermission doesn't respond_to? _rc_response!")
        end

        raise e
      ensure
        if response
          handle_preemptive_rl(response.headers, mutex, key) if response.headers[:x_ratelimit_remaining] == '0' && !mutex.locked?
        else
          Discordrb::LOGGER.ratelimit('Response was nil before trying to preemptively rate limit!')
        end
      end
    rescue RestClient::TooManyRequests => e
      # If the 429 is from the global RL, then we have to use the global mutex instead.
      mutex = @global_mutex if e.response.headers[:x_ratelimit_global] == 'true'

      unless mutex.locked?
        response = JSON.parse(e.response)
        wait_seconds = response['retry_after'].to_i / 1000.0
        Discordrb::LOGGER.ratelimit("Locking RL mutex (key: #{key}) for #{wait_seconds} seconds due to Discord rate limiting")
        trace("429 #{key.join(' ')}")

        # Wait the required time synchronized by the mutex (so other incoming requests have to wait) but only do it if
        # the mutex isn't locked already so it will only ever wait once
        sync_wait(wait_seconds, mutex)
      end

      retry
    end

    response
  end

  # Handles pre-emptive rate limiting by waiting the given mutex by the difference of the Date header to the
  # X-Ratelimit-Reset header, thus making sure we don't get 429'd in any subsequent requests.
  def handle_preemptive_rl(headers, mutex, key)
    Discordrb::LOGGER.ratelimit "RL bucket depletion detected! Date: #{headers[:date]} Reset: #{headers[:x_ratelimit_reset]}"
    delta = headers[:x_ratelimit_reset_after].to_f
    Discordrb::LOGGER.warn("Locking RL mutex (key: #{key}) for #{delta} seconds pre-emptively")
    sync_wait(delta, mutex)
  end

  # Perform rate limit tracing. All this method does is log the current backtrace to the console with the `:ratelimit`
  # level.
  # @param reason [String] the reason to include with the backtrace.
  def trace(reason)
    unless @trace
      Discordrb::LOGGER.debug("trace was called with reason #{reason}, but tracing is not enabled")
      return
    end

    Discordrb::LOGGER.ratelimit("Trace (#{reason}):")

    caller.each do |str|
      Discordrb::LOGGER.ratelimit(" #{str}")
    end
  end

  # Make an icon URL from server and icon IDs
  def icon_url(server_id, icon_id, format = 'webp')
    "#{cdn_url}/icons/#{server_id}/#{icon_id}.#{format}"
  end

  # Make an icon URL from application and icon IDs
  def app_icon_url(app_id, icon_id, format = 'webp')
    "#{cdn_url}/app-icons/#{app_id}/#{icon_id}.#{format}"
  end

  # Make a widget picture URL from server ID
  def widget_url(server_id, style = 'shield')
    "#{api_base}/guilds/#{server_id}/widget.png?style=#{style}"
  end

  # Make a splash URL from server and splash IDs
  def splash_url(server_id, splash_id, format = 'webp')
    "#{cdn_url}/splashes/#{server_id}/#{splash_id}.#{format}"
  end

  # Make a banner URL from server and banner IDs
  def banner_url(server_id, banner_id, format = 'webp')
    "#{cdn_url}/banners/#{server_id}/#{banner_id}.#{format}"
  end

  # Make an emoji icon URL from emoji ID
  def emoji_icon_url(emoji_id, format = 'webp')
    "#{cdn_url}/emojis/#{emoji_id}.#{format}"
  end

  # Make an asset URL from application and asset IDs
  def asset_url(application_id, asset_id, format = 'webp')
    "#{cdn_url}/app-assets/#{application_id}/#{asset_id}.#{format}"
  end

  # Make an achievement icon URL from application ID, achievement ID, and icon hash
  def achievement_icon_url(application_id, achievement_id, icon_hash, format = 'webp')
    "#{cdn_url}/app-assets/#{application_id}/achievements/#{achievement_id}/icons/#{icon_hash}.#{format}"
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

  # Get the gateway to be used, with additional information for sharding and
  # session start limits
  def gateway_bot(token)
    request(
      :gateway_bot,
      nil,
      :get,
      "#{api_base}/gateway/bot",
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

  # Get a list of available voice regions
  def voice_regions(token)
    request(
      :voice_regions,
      nil,
      :get,
      "#{api_base}/voice/regions",
      Authorization: token,
      content_type: :json
    )
  end
end

Discordrb::API.reset_mutexes
