# frozen_string_literal: true

module Discordrb
  # Custom errors raised in various places
  module Errors
    # Raised when authentication data is invalid or incorrect.
    class InvalidAuthenticationError < RuntimeError
      # Default message for this exception
      def message
        'User login failed due to an invalid email or password!'
      end
    end

    # Raised when a message is over the character limit
    class MessageTooLong < RuntimeError; end

    # Raised when the bot can't do something because its permissions on the server are insufficient
    class NoPermission < RuntimeError; end

    # Raised when the bot gets a HTTP 502 error, which is usually caused by Cloudflare.
    class CloudflareError < RuntimeError; end

    # Generic class for errors denoted by API error codes
    class CodeError < RuntimeError
      class << self
        # @return [Integer] The error code represented by this error class.
        attr_reader :code
      end

      # Create a new error with a particular message (the code should be defined by the class instance variable)
      # @param message [String] the message to use
      def initialize(message)
        @message = message
      end

      # @return [Integer] The error code represented by this error.
      def code
        self.class.code
      end

      # @return [String] This error's represented message
      attr_reader :message
    end

    # Create a new code error class
    # rubocop:disable Naming/MethodName
    def self.Code(code)
      classy = Class.new(CodeError)
      classy.instance_variable_set('@code', code)

      @code_classes ||= {}
      @code_classes[code] = classy

      classy
    end
    # rubocop:enable Naming/MethodName

    # @param code [Integer] The code to check
    # @return [Class] the error class for the given code
    def self.error_class_for(code)
      @code_classes[code]
    end

    # Used when Discord doesn't provide a more specific code
    UnknownError = Code(0)

    # Unknown Account
    UnknownAccount = Code(10_001)

    # Unknown Application
    UnknownApplication = Code(10_002)

    # Unknown Channel
    UnknownChannel = Code(10_003)

    # Unknown Server
    UnknownServer = Code(10_004)

    # Unknown Integration
    UnknownIntegration = Code(10_005)

    # Unknown Invite
    UnknownInvite = Code(10_006)

    # Unknown Member
    UnknownMember = Code(10_007)

    # Unknown Message
    UnknownMessage = Code(10_008)

    # Unknown Overwrite
    UnknownOverwrite = Code(10_009)

    # Unknown Provider
    UnknownProvider = Code(10_010)

    # Unknown Role
    UnknownRole = Code(10_011)

    # Unknown Token
    UnknownToken = Code(10_012)

    # Unknown User
    UnknownUser = Code(10_013)

    # Unknown Emoji
    UnknownEmoji = Code(10_014)

    # Bots cannot use this endpoint
    EndpointNotForBots = Code(20_001)

    # Only bots can use this endpoint
    EndpointOnlyForBots = Code(20_002)

    # Maximum number of servers reached (100)
    ServerLimitReached = Code(30_001)

    # Maximum number of friends reached (1000)
    FriendLimitReached = Code(30_002)

    # Maximum number of pins reached (50)
    PinLimitReached = Code(30_003)

    # Maximum number of guild roles reached (250)
    RoleLimitReached = Code(30_005)

    # Too many reactions
    ReactionLimitReached = Code(30_010)

    # Maximum number of guild channels reached (500)
    ChannelLimitReached = Code(30_013)

    # Unauthorized
    Unauthorized = Unauthorised = Code(40_001)

    # Missing Access
    MissingAccess = Code(50_001)

    # Invalid Account Type
    InvalidAccountType = Code(50_002)

    # Cannot execute action on a DM channel
    InvalidActionForDM = Code(50_003)

    # Embed Disabled
    EmbedDisabled = Code(50_004)

    # Cannot edit a message authored by another user
    MessageAuthoredByOtherUser = Code(50_005)

    # Cannot send an empty message
    MessageEmpty = Code(50_006)

    # Cannot send messages to this user
    NoMessagesToUser = Code(50_007)

    # Cannot send messages in a voice channel
    NoMessagesInVoiceChannel = Code(50_008)

    # Channel verification level is too high
    VerificationLevelTooHigh = Code(50_009)

    # OAuth2 application does not have a bot
    NoBotForApplication = Code(50_010)

    # OAuth2 application limit reached
    ApplicationLimitReached = Code(50_011)

    # Invalid OAuth State
    InvalidOAuthState = Code(50_012)

    # Missing Permissions
    MissingPermissions = Code(50_013)

    # Invalid authentication token
    InvalidAuthToken = Code(50_014)

    # Note is too long
    NoteTooLong = Code(50_015)

    # Provided too few or too many messages to delete. Must provide at least 2 and fewer than 100 messages to delete.
    InvalidBulkDeleteCount = Code(50_016)

    # A message can only be pinned to the channel it was sent in
    CannotPinInDifferentChannel = Code(50_019)

    # Cannot execute action on a system message
    InvalidActionForSystemMessage = Code(50_021)

    # A message provided was too old to bulk delete
    MessageTooOld = Code(50_034)

    # Invalid Form Body
    InvalidFormBody = Code(50_035)

    # An invite was accepted to a guild the application's bot is not in
    MissingBotMember = Code(50_036)

    # Reaction Blocked
    ReactionBlocked = Code(90_001)
  end
end
