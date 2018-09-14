# frozen_string_literal: true

require 'rest-client'
require 'json'
require 'time'

require 'discordrb/errors'

# List of methods representing endpoints in Discord's API
module Discordrb::API
  # The base URL of the Discord REST API.
  APIBASE = 'https://discordapp.com/api/v7'.freeze

  # The URL of Discord's CDN
  CDN_URL = 'https://cdn.discordapp.com'.freeze

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

  # @return [String] the bot name, previously specified using #bot_name=.
  def bot_name
    @bot_name
  end

  # Sets the bot name to something.
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
    required = "DiscordBot (https://github.com/meew0/discordrb, v#{Discordrb::VERSION})"
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

  # A response from Discord's API
  Response = Struct.new(:code, :body, :headers) do
    # @return [true, false] whether this reponse repesents a successful
    #   (2XX series) request
    def success?
      (200..299).cover?(code)
    end

    # @return [true, false] whether the request can be retried
    def fatal?
      [400, 401, 403, 404, 500].include?(code)
    end

    # @return [true, false] whether the request is being rate limited
    def too_many_requests?
      code == 429
    end

    # @return [true, false] whether this reponse's body contains JSON content
    def json_body?
      headers[:content_type] == 'application/json'
    end
  end

  # Performs an HTTP request to Discord's API
  # @param method [Symbol] HTTP method
  # @param resource [String] API resource (including querystring)
  # @param headers [Hash] HTTP headers
  # @param payload [String] HTTP request body
  # @return [Response]
  def raw_request(method, resource, headers, payload)
    Discordrb::LOGGER.info("[HTTP OUT] #{method} #{resource}")
    url = api_base + URI.encode(resource)
    RestClient::Request.execute(method: method, url: url, headers: headers, payload: payload) do |response, _request, _result|
      Discordrb::LOGGER.info("[HTTP IN] #{response.code} (#{response.body.size})")
      case response.code
      when 200..299, 400..499, 502
        # Successful, Client Error
        Response.new(response.code, response.body, response.headers)
      else
        # TODO: Fall back on RestClient's handling for any other code value (for now)
        Discordrb::LOGGER.warn("Unhandled HTTP code #{response.code}, falling back to RestClient:\n#{response.inspect}")
        response.return!(&block)
      end
    end
  end

  # Make an API request, including rate limit handling.
  def request(key, major_parameter, method, resource, headers: {}, payload: nil)
    # Obtain this requests bucket mutex, and wait for it to be unlocked
    bucket = [key, major_parameter].freeze
    mutex = @mutexes[bucket] ||= Mutex.new
    mutex_wait(mutex)
    mutex_wait(@global_mutex) if @global_mutex.locked?

    # Apply custom user agent
    headers[:user_agent] = user_agent

    # Serialize payload if JSON content is being sent
    payload = payload.to_json if headers[:content_type] == :json

    # Execute the request
    response = raw_request(method, resource, headers, payload)

    # Handle preemptive rate limiting
    if response.headers[:x_ratelimit_remaining] == '0' && !mutex.locked?
      handle_preemptive_rl(response.headers, mutex, key)
    end

    # Decode body if we received JSON
    body = if response.json_body?
             JSON.parse(response.body)
           else
             response.body
           end

    # If it was a successful request, we have nothing left to do
    # except return the body:
    return body if response.success?

    # Handle exceeded rate limit
    if response.too_many_requests?
      mutex = @global_mutex if response.headers[:x_ratelimit_global] == 'true'
      wait_seconds = body['retry_after'].to_i / 1000.0
      handle_exceeded_rl(wait_seconds, mutex, key)
    end

    # Handle fatal response
    if response.fatal?
      code = body['code']

      # TODO: Generic APIError class
      raise "Unknown API error: #{response.inspect}" unless code

      # Decode custom error class, and raise it
      code_error_class = Discordrb::Errors.error_class_for(code)
      raise code_error_class, body['message']
    end

    # Retry recursively
    Discordrb::LOGGER.warn("Request failed with #{response.code}, retrying")
    request(bucket, method, resource, headers, payload)
  end

  # Handles premeptive ratelimiting by waiting the given mutex by the difference of the Date header to the
  # X-Ratelimit-Reset header, thus making sure we don't get 429'd in any subsequent requests.
  def handle_preemptive_rl(headers, mutex, key)
    Discordrb::LOGGER.ratelimit "RL bucket depletion detected! Date: #{headers[:date]} Reset: #{headers[:x_ratelimit_reset]}"

    now = Time.rfc2822(headers[:date])
    reset = Time.at(headers[:x_ratelimit_reset].to_i)

    delta = reset - now

    Discordrb::LOGGER.warn("Locking RL mutex (key: #{key}) for #{delta} seconds preemptively")
    sync_wait(delta, mutex)
  end

  def handle_exceeded_rl(wait_seconds, mutex, key)
    Discordrb::LOGGER.ratelimit("Locking RL mutex (key: #{key}) for #{wait_seconds} seconds due to Discord rate limiting")
    trace("429 #{key.join(' ')}")

    # Wait the required time synchronized by the mutex (so other incoming requests have to wait) but only do it if
    # the mutex isn't locked already so it will only ever wait once
    sync_wait(wait_seconds, mutex)
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
      Discordrb::LOGGER.ratelimit(' ' + str)
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

  # Make an emoji icon URL from emoji ID
  def emoji_icon_url(emoji_id, format = 'webp')
    "#{cdn_url}/emojis/#{emoji_id}.#{format}"
  end

  # Login to the server
  def login(email, password)
    request(
      :auth_login,
      nil,
      :POST,
      '/auth/login',
      headers: { content_type: :json },
      payload: { email: email, password: password }
    )
  end

  # Logout from the server
  def logout(token)
    request(
      :auth_logout,
      nil,
      :POST,
      '/auth/logout',
      headers: { Authorization: token }
    )
  end

  # Create an OAuth application
  def create_oauth_application(token, name, redirect_uris)
    request(
      :oauth2_applications,
      nil,
      :POST,
      '/oauth2/applications',
      headers: { Authorization: token, content_type: :json },
      payload: { name: name, redirect_uris: redirect_uris }
    )
  end

  # Change an OAuth application's properties
  def update_oauth_application(token, name, redirect_uris, description = '', icon = nil)
    request(
      :oauth2_applications,
      nil,
      :PUT,
      '/oauth2/applications',
      headers: { Authorization: token, content_type: :json },
      payload: { name: name, redirect_uris: redirect_uris, description: description, icon: icon }
    )
  end

  # Get the bot's OAuth application's information
  def oauth_application(token)
    request(
      :oauth2_applications_me,
      nil,
      :GET,
      '/oauth2/applications/@me',
      headers: { Authorization: token }
    )
  end

  # Acknowledge that a message has been received
  # The last acknowledged message will be sent in the ready packet,
  # so this is an easy way to catch up on messages
  def acknowledge_message(token, channel_id, message_id)
    request(
      :channels_cid_messages_mid_ack,
      nil, # This endpoint is unavailable for bot accounts and thus isn't subject to its rate limit requirements.
      :POST,
      "/channels/#{channel_id}/messages/#{message_id}/ack",
      headers: { Authorization: token }
    )
  end

  # Get the gateway to be used
  def gateway(token)
    request(
      :gateway,
      nil,
      :GET,
      '/gateway',
      headers: { Authorization: token }
    )
  end

  # Validate a token (this request will fail if the token is invalid)
  def validate_token(token)
    request(
      :auth_login,
      nil,
      :POST,
      '/auth/login',
      headers: { Authorization: token, content_type: :json },
      payload: {}
    )
  end

  # Get a list of available voice regions
  def voice_regions(token)
    request(
      :voice_regions,
      nil,
      :GET,
      '/voice/regions',
      headers: { Authorization: token }
    )
  end
end

Discordrb::API.reset_mutexes
