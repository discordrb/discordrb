# frozen_string_literal: true

module Discordrb
  # Contains information about user activities such as the game they are playing,
  # music they are listening to, or their twitch stream.
  class Activity
    # Values corresponding to the flags bitmask
    FLAGS = {
      instance: 1 << 0, # this activity is an instanced game session
      join: 1 << 1, # this activity is joinable
      spectate: 1 << 2, # this activity can be spectated
      join_request: 1 << 3, # this activity allows asking to join
      sync: 1 << 4, # this activity is a spotify track
      play: 1 << 5 # this game can be played or opened from discord
    }.freeze

    # @return [String] the activity's name
    attr_reader :name

    # @return [Integer, nil] activity type. Can be {GAME}, {STREAMING}, {LISTENING}, {CUSTOM}
    attr_reader :type

    # @return [String, nil] stream URL, when the activity type is {STREAMING}
    attr_reader :url

    # @return [String, nil] the application ID for the game
    attr_reader :application_id

    # @return [String, nil] details about what the player is currently doing
    attr_reader :details

    # @return [String, nil] the user's current party status
    attr_reader :state

    # @return [true, false] whether or not the activity is an instanced game session
    attr_reader :instance

    # @return [Integer] a bitmask of activity flags
    # @see FLAGS
    attr_reader :flags

    # @return [Timestamps, nil] times for the start and/or end of the activity
    attr_reader :timestamps

    # @return [Secrets, nil] secrets for rich presence joining and spectating
    attr_reader :secrets

    # @return [Assets, nil] images for the presence and their texts
    attr_reader :assets

    # @return [Party, nil] information about the player's current party
    attr_reader :party

    # @return [Emoji, nil] emoji data for custom statuses
    attr_reader :emoji

    # Type indicating the activity is for a game
    GAME = 0
    # Type indicating the activity is a stream
    STREAMING = 1
    # Type indicating the activity is for music
    LISTENING = 2
    # This type is currently unused in the client but can be reported by bots
    WATCHING = 3
    # Type indicating the activity is a custom status
    CUSTOM = 4

    # @!visibility private
    def initialize(data, bot)
      @name = data['name']
      @type = data['type']
      @url = data['url']
      @application_id = data['application_id']
      @details = data['details']
      @state = data['state']
      @instance = data['instance']
      @flags = data['flags'] || 0

      @timestamps = Timestamps.new(data['timestamps']) if data['timestamps']
      @secrets = Secret.new(data['secrets']) if data['secrets']
      @assets = Assets.new(data['assets']) if data['assets']
      @party = Party.new(data['party']) if data['party']
      # Merge of #671 requires this to be changed.
      @emoji = Emoji.new(data['emoji'], bot, nil) if data['emoji']
    end

    # @return [true, false] Whether or not the `join` flag is set for this activity
    def join?
      flag_set? :join
    end

    # @return [true, false] Whether or not the `spectate` flag is set for this activity
    def spectate?
      flag_set? :spectate
    end

    # @return [true, false] Whether or not the `join_request` flag is set for this activity
    def join_request?
      flag_set? :join_request
    end

    # @return [true, false] Whether or not the `sync` flag is set for this activity
    def sync?
      flag_set? :sync
    end

    # @return [true, false] Whether or not the `play` flag is set for this activity
    def play?
      flag_set? :play
    end

    # @return [true, false] Whether or not the `instance` flag is set for this activity
    def instance?
      @instance || flag_set?(:instance)
    end

    # @!visibility private
    def flag_set?(sym)
      !(@flags & FLAGS[sym]).zero?
    end

    # Timestamps for the start and end of instanced activities
    class Timestamps
      # @return [Time, nil]
      attr_reader :start

      # @return [Time, nil]
      attr_reader :end

      # @!visibility private
      def initialize(data)
        @start = Time.at(data['start'] / 1000) if data['start']
        @end = Time.at(data['end'] / 1000) if data['end']
      end
    end

    # Contains secrets used for rich presence
    class Secrets
      # @return [String, nil] secret for joining a party
      attr_reader :join

      # @return [String, nil] secret for spectating
      attr_reader :spectate

      # @return [String, nil] secret for a specific instanced match
      attr_reader :match

      # @!visibility private
      def initialize(data)
        @join = data['join']
        @spectate = data['spectate']
        @match = data['match']
      end
    end

    # Assets for rich presence images and hover text
    class Assets
      # @return [String, nil] the asset id for the large image of this activity
      attr_reader :large_image

      # @return [String, nil] text displayed when hovering over the large iamge
      attr_reader :large_text

      # @return [String, nil] the asset id for the small image of this activity
      attr_reader :small_image

      # @return [String, nil]
      attr_reader :small_text

      # @!visibility private
      def initialize(data)
        @large_image = data['large_image']
        @large_text = data['large_text']
        @small_image = data['small_image']
        @small_text = data['small_text']
      end
    end

    # Contains information about an activity's party
    class Party
      # @return [String, nil]
      attr_reader :id

      # @return [Integer, nil]
      attr_reader :current_size

      # @return [Integer, nil]
      attr_reader :max_size

      # @!visibility private
      def initialize(data)
        @id = data['id']
        @current_size, @max_size = data['size']
      end
    end
  end

  # A class for accessing a users activities
  class ActivitySet
    # @!visibility private
    def initialize(activities)
      @activities = activities
    end

    # @return [Array<Activity>]
    def all
      @activities
    end

    # @return [Activity, nil] the first activity of type {Activity::GAME}
    def game
      @activities.find { |act| act.type == Activity::GAME }
    end

    # @return [Activity, nil] the first activity of type {Activity::STREAMING}
    def streaming
      @activities.find { |act| act.type == Activity::STREAMING }
    end

    # @return [Activity, nil] the first activity of type {Activity::LISTENING}
    def listening
      @activities.find { |act| act.type == Activity::LISTENING }
    end

    # @return [Activity, nil] the first activity of type {Activity::WATCHING}
    def watching
      @activities.find { |act| act.type == Activity::WATCHING }
    end

    # @return [Activity, nil] the first activity of type {Activity::CUSTOM}
    def custom_status
      @activities.find { |act| act.type == Activity::CUSTOM }
    end
  end
end
