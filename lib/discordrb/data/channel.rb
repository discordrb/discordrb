# frozen_string_literal: true

module Discordrb
  # A Discord channel, including data like the topic
  class Channel
    include IDObject

    # Map of channel types
    TYPES = {
      text: 0,
      dm: 1,
      voice: 2,
      group: 3,
      category: 4,
      news: 5,
      store: 6
    }.freeze

    # @return [String] this channel's name.
    attr_reader :name

    # @return [Server, nil] the server this channel is on. If this channel is a PM channel, it will be nil.
    attr_reader :server

    # @return [Integer, nil] the ID of the parent channel, if this channel is inside a category
    attr_reader :parent_id

    # @return [Integer] the type of this channel
    # @see TYPES
    attr_reader :type

    # @return [Integer, nil] the ID of the owner of the group channel or nil if this is not a group channel.
    attr_reader :owner_id

    # @return [Array<Recipient>, nil] the array of recipients of the private messages, or nil if this is not a Private channel
    attr_reader :recipients

    # @return [String] the channel's topic
    attr_reader :topic

    # @return [Integer] the bitrate (in bps) of the channel
    attr_reader :bitrate

    # @return [Integer] the amount of users that can be in the channel. `0` means it is unlimited.
    attr_reader :user_limit
    alias_method :limit, :user_limit

    # @return [Integer] the channel's position on the channel list
    attr_reader :position

    # @return [true, false] if this channel is marked as nsfw
    attr_reader :nsfw
    alias_method :nsfw?, :nsfw

    # @return [Integer] the amount of time (in seconds) users need to wait to send in between messages.
    attr_reader :rate_limit_per_user
    alias_method :slowmode_rate, :rate_limit_per_user

    # @return [true, false] whether or not this channel is a PM or group channel.
    def private?
      pm? || group?
    end

    # @return [String] a string that will mention the channel as a clickable link on Discord.
    def mention
      "<##{@id}>"
    end

    # @return [Recipient, nil] the recipient of the private messages, or nil if this is not a PM channel
    def recipient
      @recipients.first if pm?
    end

    # @!visibility private
    def initialize(data, bot, server = nil)
      @bot = bot
      # data is sometimes a Hash and other times an array of Hashes, you only want the last one if it's an array
      data = data[-1] if data.is_a?(Array)

      @id = data['id'].to_i
      @type = data['type'] || 0
      @topic = data['topic']
      @bitrate = data['bitrate']
      @user_limit = data['user_limit']
      @position = data['position']
      @parent_id = data['parent_id'].to_i if data['parent_id']

      if private?
        @recipients = []
        data['recipients']&.each do |recipient|
          recipient_user = bot.ensure_user(recipient)
          @recipients << Recipient.new(recipient_user, self, bot)
        end
        if pm?
          @name = @recipients.first.username
        else
          @name = data['name']
          @owner_id = data['owner_id']
        end
      else
        @name = data['name']
        @server = server || bot.server(data['guild_id'].to_i)
      end

      @nsfw = data['nsfw'] || false
      @rate_limit_per_user = data['rate_limit_per_user'] || 0

      process_permission_overwrites(data['permission_overwrites'])
    end

    # @return [true, false] whether or not this channel is a text channel
    def text?
      @type.zero?
    end

    # @return [true, false] whether or not this channel is a PM channel.
    def pm?
      @type == 1
    end

    # @return [true, false] whether or not this channel is a voice channel.
    def voice?
      @type == 2
    end

    # @return [true, false] whether or not this channel is a group channel.
    def group?
      @type == 3
    end

    # @return [true, false] whether or not this channel is a category channel.
    def category?
      @type == 4
    end

    # @return [true, false] whether or not this channel is a news channel.
    def news?
      @type == 5
    end

    # @return [true, false] whether or not this channel is a store channel.
    def store?
      @type == 6
    end

    # @return [Channel, nil] the category channel, if this channel is in a category
    def category
      @bot.channel(@parent_id) if @parent_id
    end

    alias_method :parent, :category

    # Sets this channels parent category
    # @param channel [Channel, String, Integer] the target category channel, or its ID
    # @raise [ArgumentError] if the target channel isn't a category
    def category=(channel)
      channel = @bot.channel(channel)
      raise ArgumentError, 'Cannot set parent category to a channel that isn\'t a category' unless channel.category?

      update_channel_data(parent_id: channel.id)
    end

    alias_method :parent=, :category=

    # Sorts this channel's position to follow another channel.
    # @param other [Channel, String, Integer, nil] The channel, or its ID, below which this channel should be sorted. If the given
    #   channel is a category, this channel will be sorted at the top of that category. If it is `nil`, the channel will
    #   be sorted at the top of the channel list.
    # @param lock_permissions [true, false] Whether the channel's permissions should be synced to the category's
    def sort_after(other = nil, lock_permissions = false)
      raise TypeError, 'other must be one of Channel, NilClass, String, or Integer' unless other.is_a?(Channel) || other.nil? || other.respond_to?(:resolve_id)

      other = @bot.channel(other.resolve_id) if other

      # Container for the API request payload
      move_argument = []

      if other
        raise ArgumentError, 'Can only sort a channel after a channel of the same type!' unless other.category? || (@type == other.type)

        raise ArgumentError, 'Can only sort a channel after a channel in the same server!' unless other.server == server

        # Store `others` parent (or if `other` is a category itself)
        parent = if category? && other.category?
                   # If we're sorting two categories, there is no new parent
                   nil
                 elsif other.category?
                   # `other` is the category this channel will be moved into
                   other
                 else
                   # `other`'s parent is the category this channel will be
                   # moved into (if it exists)
                   other.parent
                 end
      end

      # Collect and sort the IDs within the context (category or not) that we
      # need to form our payload with
      ids = if parent
              parent.children
            else
              @server.channels.reject(&:parent_id).select { |c| c.type == @type }
            end.sort_by(&:position).map(&:id)

      # Move our channel ID after the target ID by deleting it,
      # getting the index of `other`, and inserting it after.
      ids.delete(@id) if ids.include?(@id)
      index = other ? (ids.index { |c| c == other.id } || -1) + 1 : 0
      ids.insert(index, @id)

      # Generate `move_argument`, making the positions in order from how
      # we have sorted them in the above logic
      ids.each_with_index do |id, pos|
        # These keys are present in each element
        hash = { id: id, position: pos }

        # Conditionally add `lock_permissions` and `parent_id` if we're
        # iterating past ourselves
        if id == @id
          hash[:lock_permissions] = true if lock_permissions
          hash[:parent_id] = parent.nil? ? nil : parent.id
        end

        # Add it to the stack
        move_argument << hash
      end

      API::Server.update_channel_positions(@bot.token, @server.id, move_argument)
    end

    # Sets whether this channel is NSFW
    # @param nsfw [true, false]
    # @raise [ArgumentError] if value isn't one of true, false
    def nsfw=(nsfw)
      raise ArgumentError, 'nsfw value must be true or false' unless nsfw.is_a?(TrueClass) || nsfw.is_a?(FalseClass)

      update_channel_data(nsfw: nsfw)
    end

    # This channel's permission overwrites
    # @overload permission_overwrites
    #   The overwrites represented as a hash of role/user ID
    #   to an Overwrite object
    #   @return [Hash<Integer => Overwrite>] the channel's permission overwrites
    # @overload permission_overwrites(type)
    #   Return an array of a certain type of overwrite
    #   @param type [Symbol] the kind of overwrite to return
    #   @return [Array<Overwrite>]
    def permission_overwrites(type = nil)
      return @permission_overwrites unless type

      @permission_overwrites.values.select { |e| e.type == type }
    end

    alias_method :overwrites, :permission_overwrites

    # Bulk sets this channels permission overwrites
    # @param overwrites [Array<Overwrite>]
    def permission_overwrites=(overwrites)
      update_channel_data(permission_overwrites: overwrites)
    end

    # Sets the amount of time (in seconds) users have to wait in between sending messages.
    # @param rate [Integer]
    # @raise [ArgumentError] if value isn't between 0 and 120
    def rate_limit_per_user=(rate)
      raise ArgumentError, 'rate_limit_per_user must be between 0 and 120' unless rate.between?(0, 120)

      update_channel_data(rate_limit_per_user: rate)
    end

    alias_method :slowmode_rate=, :rate_limit_per_user=

    # Syncs this channels overwrites with its parent category
    # @raise [RuntimeError] if this channel is not in a category
    def sync_overwrites
      raise 'Cannot sync overwrites on a channel with no parent category' unless parent

      self.permission_overwrites = parent.permission_overwrites
    end

    alias_method :sync, :sync_overwrites

    # @return [true, false, nil] whether this channels permissions match the permission overwrites of the category that it's in, or nil if it is not in a category
    def synchronized?
      return unless parent

      permission_overwrites == parent.permission_overwrites
    end

    alias_method :synced?, :synchronized?

    # Returns the children of this channel, if it is a category. Otherwise returns an empty array.
    # @return [Array<Channel>]
    def children
      return [] unless category?

      server.channels.select { |c| c.parent_id == id }
    end

    alias_method :channels, :children

    # Returns the text channels in this category, if it is a category channel. Otherwise returns an empty array.
    # @return [Array<Channel>]
    def text_channels
      children.select(&:text?)
    end

    # Returns the voice channels in this category, if it is a category channel. Otherwise returns an empty array.
    # @return [Array<Channel>]
    def voice_channels
      children.select(&:voice?)
    end

    # @return [Overwrite] any member-type permission overwrites on this channel
    def member_overwrites
      permission_overwrites :member
    end

    # @return [Overwrite] any role-type permission overwrites on this channel
    def role_overwrites
      permission_overwrites :role
    end

    # @return [true, false] whether or not this channel is the default channel
    def default_channel?
      server.default_channel == self
    end

    alias_method :default?, :default_channel?

    # @return [true, false] whether or not this channel has slowmode enabled
    def slowmode?
      @rate_limit_per_user != 0
    end

    # Sends a message to this channel.
    # @param content [String] The content to send. Should not be longer than 2000 characters or it will result in an error.
    # @param tts [true, false] Whether or not this message should be sent using Discord text-to-speech.
    # @param embed [Hash, Discordrb::Webhooks::Embed, nil] The rich embed to append to this message.
    # @param attachments [Array<File>] Files that can be referenced in embeds via `attachment://file.png`
    # @param allowed_mentions [Hash, Discordrb::AllowedMentions, false, nil] Mentions that are allowed to ping on this message. `false` disables all pings
    # @param message_reference [Message, String, Integer, nil] The message, or message ID, to reply to if any.
    # @return [Message] the message that was sent.
    def send_message(content, tts = false, embed = nil, attachments = nil, allowed_mentions = nil, message_reference = nil)
      @bot.send_message(@id, content, tts, embed, attachments, allowed_mentions, message_reference)
    end

    alias_method :send, :send_message

    # Sends a temporary message to this channel.
    # @param content [String] The content to send. Should not be longer than 2000 characters or it will result in an error.
    # @param timeout [Float] The amount of time in seconds after which the message sent will be deleted.
    # @param tts [true, false] Whether or not this message should be sent using Discord text-to-speech.
    # @param embed [Hash, Discordrb::Webhooks::Embed, nil] The rich embed to append to this message.
    # @param attachments [Array<File>] Files that can be referenced in embeds via `attachment://file.png`
    # @param allowed_mentions [Hash, Discordrb::AllowedMentions, false, nil] Mentions that are allowed to ping on this message. `false` disables all pings
    # @param message_reference [Message, String, Integer, nil] The message, or message ID, to reply to if any.
    def send_temporary_message(content, timeout, tts = false, embed = nil, attachments = nil, allowed_mentions = nil, message_reference = nil)
      @bot.send_temporary_message(@id, content, timeout, tts, embed, attachments, allowed_mentions, message_reference)
    end

    # Convenience method to send a message with an embed.
    # @example Send a message with an embed
    #   channel.send_embed do |embed|
    #     embed.title = 'The Ruby logo'
    #     embed.image = Discordrb::Webhooks::EmbedImage.new(url: 'https://www.ruby-lang.org/images/header-ruby-logo.png')
    #   end
    # @param message [String] The message that should be sent along with the embed. If this is the empty string, only the embed will be shown.
    # @param embed [Discordrb::Webhooks::Embed, nil] The embed to start the building process with, or nil if one should be created anew.
    # @param attachments [Array<File>] Files that can be referenced in embeds via `attachment://file.png`
    # @param tts [true, false] Whether or not this message should be sent using Discord text-to-speech.
    # @param allowed_mentions [Hash, Discordrb::AllowedMentions, false, nil] Mentions that are allowed to ping on this message. `false` disables all pings
    # @param message_reference [Message, String, Integer, nil] The message, or message ID, to reply to if any.
    # @yield [embed] Yields the embed to allow for easy building inside a block.
    # @yieldparam embed [Discordrb::Webhooks::Embed] The embed from the parameters, or a new one.
    # @return [Message] The resulting message.
    def send_embed(message = '', embed = nil, attachments = nil, tts = false, allowed_mentions = nil, message_reference = nil)
      embed ||= Discordrb::Webhooks::Embed.new
      yield(embed) if block_given?
      send_message(message, tts, embed, attachments, allowed_mentions, message_reference)
    end

    # Sends multiple messages to a channel
    # @param content [Array<String>] The messages to send.
    def send_multiple(content)
      content.each { |e| send_message(e) }
    end

    # Splits a message into chunks whose length is at most the Discord character limit, then sends them individually.
    # Useful for sending long messages, but be wary of rate limits!
    def split_send(content)
      send_multiple(Discordrb.split_message(content))
      nil
    end

    # Sends a file to this channel. If it is an image, it will be embedded.
    # @param file [File] The file to send. There's no clear size limit for this, you'll have to attempt it for yourself (most non-image files are fine, large images may fail to embed)
    # @param caption [string] The caption for the file.
    # @param tts [true, false] Whether or not this file's caption should be sent using Discord text-to-speech.
    # @param filename [String] Overrides the filename of the uploaded file
    # @param spoiler [true, false] Whether or not this file should appear as a spoiler.
    # @example Send a file from disk
    #   channel.send_file(File.open('rubytaco.png', 'r'))
    def send_file(file, caption: nil, tts: false, filename: nil, spoiler: nil)
      @bot.send_file(@id, file, caption: caption, tts: tts, filename: filename, spoiler: spoiler)
    end

    # Deletes a message on this channel. Mostly useful in case a message needs to be deleted when only the ID is known
    # @param message [Message, String, Integer, String, Integer] The message, or its ID, that should be deleted.
    def delete_message(message)
      API::Channel.delete_message(@bot.token, @id, message.resolve_id)
    end

    # Permanently deletes this channel
    # @param reason [String] The reason the for the channel deletion.
    def delete(reason = nil)
      API::Channel.delete(@bot.token, @id, reason)
    end

    # Sets this channel's name. The name must be alphanumeric with dashes, unless this is a voice channel (then there are no limitations)
    # @param name [String] The new name.
    def name=(name)
      update_channel_data(name: name)
    end

    # Sets this channel's topic.
    # @param topic [String] The new topic.
    def topic=(topic)
      raise 'Tried to set topic on voice channel' if voice?

      update_channel_data(topic: topic)
    end

    # Sets this channel's bitrate.
    # @param bitrate [Integer] The new bitrate (in bps). Number has to be between 8000-96000 (128000 for VIP servers)
    def bitrate=(bitrate)
      raise 'Tried to set bitrate on text channel' if text?

      update_channel_data(bitrate: bitrate)
    end

    # Sets this channel's user limit.
    # @param limit [Integer] The new user limit. `0` for unlimited, has to be a number between 0-99
    def user_limit=(limit)
      raise 'Tried to set user_limit on text channel' if text?

      update_channel_data(user_limit: limit)
    end

    alias_method :limit=, :user_limit=

    # Sets this channel's position in the list.
    # @param position [Integer] The new position.
    def position=(position)
      update_channel_data(position: position)
    end

    # Defines a permission overwrite for this channel that sets the specified thing to the specified allow and deny
    # permission sets, or change an existing one.
    # @overload define_overwrite(overwrite)
    #   @param thing [Overwrite] an Overwrite object to apply to this channel
    #   @param reason [String] The reason the for defining the overwrite.
    # @overload define_overwrite(thing, allow, deny)
    #   @param thing [User, Role] What to define an overwrite for.
    #   @param allow [#bits, Permissions, Integer] The permission sets that should receive an `allow` override (i.e. a
    #     green checkmark on Discord)
    #   @param deny [#bits, Permissions, Integer] The permission sets that should receive a `deny` override (i.e. a red
    #     cross on Discord)
    #   @param reason [String] The reason the for defining the overwrite.
    #   @example Define a permission overwrite for a user that can then mention everyone and use TTS, but not create any invites
    #     allow = Discordrb::Permissions.new
    #     allow.can_mention_everyone = true
    #     allow.can_send_tts_messages = true
    #
    #     deny = Discordrb::Permissions.new
    #     deny.can_create_instant_invite = true
    #
    #     channel.define_overwrite(user, allow, deny)
    def define_overwrite(thing, allow = 0, deny = 0, reason: nil)
      unless thing.is_a? Overwrite
        allow_bits = allow.respond_to?(:bits) ? allow.bits : allow
        deny_bits = deny.respond_to?(:bits) ? deny.bits : deny

        thing = Overwrite.new thing, allow: allow_bits, deny: deny_bits
      end

      API::Channel.update_permission(@bot.token, @id, thing.id, thing.allow.bits, thing.deny.bits, thing.type, reason)
    end

    # Deletes a permission overwrite for this channel
    # @param target [Member, User, Role, Profile, Recipient, String, Integer] What permission overwrite to delete
    #   @param reason [String] The reason the for the overwrite deletion.
    def delete_overwrite(target, reason = nil)
      raise 'Tried deleting a overwrite for an invalid target' unless target.is_a?(Member) || target.is_a?(User) || target.is_a?(Role) || target.is_a?(Profile) || target.is_a?(Recipient) || target.respond_to?(:resolve_id)

      API::Channel.delete_permission(@bot.token, @id, target.resolve_id, reason)
    end

    # Updates the cached data from another channel.
    # @note For internal use only
    # @!visibility private
    def update_from(other)
      @name = other.name
      @position = other.position
      @topic = other.topic
      @recipients = other.recipients
      @bitrate = other.bitrate
      @user_limit = other.user_limit
      @permission_overwrites = other.permission_overwrites
      @nsfw = other.nsfw
      @parent_id = other.parent_id
      @rate_limit_per_user = other.rate_limit_per_user
    end

    # The list of users currently in this channel. For a voice channel, it will return all the members currently
    # in that channel. For a text channel, it will return all online members that have permission to read it.
    # @return [Array<Member>] the users in this channel
    def users
      if text?
        @server.online_members(include_idle: true).select { |u| u.can_read_messages? self }
      elsif voice?
        @server.voice_states.map { |id, voice_state| @server.member(id) if !voice_state.voice_channel.nil? && voice_state.voice_channel.id == @id }.compact
      end
    end

    # Retrieves some of this channel's message history.
    # @param amount [Integer] How many messages to retrieve. This must be less than or equal to 100, if it is higher
    #   than 100 it will be treated as 100 on Discord's side.
    # @param before_id [Integer] The ID of the most recent message the retrieval should start at, or nil if it should
    #   start at the current message.
    # @param after_id [Integer] The ID of the oldest message the retrieval should start at, or nil if it should start
    #   as soon as possible with the specified amount.
    # @param around_id [Integer] The ID of the message retrieval should start from, reading in both directions
    # @example Count the number of messages in the last 50 messages that contain the letter 'e'.
    #   message_count = channel.history(50).count {|message| message.content.include? "e"}
    # @example Get the last 10 messages before the provided message.
    #   last_ten_messages = channel.history(10, message.id)
    # @return [Array<Message>] the retrieved messages.
    def history(amount, before_id = nil, after_id = nil, around_id = nil)
      logs = API::Channel.messages(@bot.token, @id, amount, before_id, after_id, around_id)
      JSON.parse(logs).map { |message| Message.new(message, @bot) }
    end

    # Retrieves message history, but only message IDs for use with prune.
    # @note For internal use only
    # @!visibility private
    def history_ids(amount, before_id = nil, after_id = nil, around_id = nil)
      logs = API::Channel.messages(@bot.token, @id, amount, before_id, after_id, around_id)
      JSON.parse(logs).map { |message| message['id'].to_i }
    end

    # Returns a single message from this channel's history by ID.
    # @param message_id [Integer] The ID of the message to retrieve.
    # @return [Message, nil] the retrieved message, or `nil` if it couldn't be found.
    def load_message(message_id)
      response = API::Channel.message(@bot.token, @id, message_id)
      Message.new(JSON.parse(response), @bot)
    rescue RestClient::ResourceNotFound
      nil
    end

    alias_method :message, :load_message

    # Requests all pinned messages in a channel.
    # @return [Array<Message>] the received messages.
    def pins
      msgs = API::Channel.pinned_messages(@bot.token, @id)
      JSON.parse(msgs).map { |msg| Message.new(msg, @bot) }
    end

    # Delete the last N messages on this channel.
    # @param amount [Integer] The amount of message history to consider for pruning. Must be a value between 2 and 100 (Discord limitation)
    # @param strict [true, false] Whether an error should be raised when a message is reached that is too old to be bulk
    #   deleted. If this is false only a warning message will be output to the console.
    # @param reason [String, nil] The reason for pruning
    # @raise [ArgumentError] if the amount of messages is not a value between 2 and 100
    # @yield [message] Yields each message in this channels history for filtering the messages to delete
    # @example Pruning messages from a specific user ID
    #   channel.prune(100) { |m| m.author.id == 83283213010599936 }
    # @return [Integer] The amount of messages that were successfully deleted
    def prune(amount, strict = false, reason = nil, &block)
      raise ArgumentError, 'Can only delete between 1 and 100 messages!' unless amount.between?(1, 100)

      messages =
        if block
          history(amount).select(&block).map(&:id)
        else
          history_ids(amount)
        end

      case messages.size
      when 0
        0
      when 1
        API::Channel.delete_message(@bot.token, @id, messages.first, reason)
        1
      else
        bulk_delete(messages, strict, reason)
      end
    end

    # Deletes a collection of messages
    # @param messages [Array<Message, String, Integer>] the messages (or message IDs) to delete. Total must be an amount between 2 and 100 (Discord limitation)
    # @param strict [true, false] Whether an error should be raised when a message is reached that is too old to be bulk
    #   deleted. If this is false only a warning message will be output to the console.
    # @param reason [String, nil] The reason for deleting the messages
    # @raise [ArgumentError] if the amount of messages is not a value between 2 and 100
    # @return [Integer] The amount of messages that were successfully deleted
    def delete_messages(messages, strict = false, reason = nil)
      raise ArgumentError, 'Can only delete between 2 and 100 messages!' unless messages.count.between?(2, 100)

      messages.map!(&:resolve_id)
      bulk_delete(messages, strict, reason)
    end

    # Updates the cached permission overwrites
    # @note For internal use only
    # @!visibility private
    def update_overwrites(overwrites)
      @permission_overwrites = overwrites
    end

    # Add an {Await} for a message in this channel. This is identical in functionality to adding a
    # {Discordrb::Events::MessageEvent} await with the `in` attribute as this channel.
    # @see Bot#add_await
    # @deprecated Will be changed to blocking behavior in v4.0. Use {#await!} instead.
    def await(key, attributes = {}, &block)
      @bot.add_await(key, Discordrb::Events::MessageEvent, { in: @id }.merge(attributes), &block)
    end

    # Add a blocking {Await} for a message in this channel. This is identical in functionality to adding a
    # {Discordrb::Events::MessageEvent} await with the `in` attribute as this channel.
    # @see Bot#add_await!
    def await!(attributes = {}, &block)
      @bot.add_await!(Discordrb::Events::MessageEvent, { in: @id }.merge(attributes), &block)
    end

    # Creates a new invite to this channel.
    # @param max_age [Integer] How many seconds this invite should last.
    # @param max_uses [Integer] How many times this invite should be able to be used.
    # @param temporary [true, false] Whether membership should be temporary (kicked after going offline).
    # @param unique [true, false] If true, Discord will always send a unique invite instead of possibly re-using a similar one
    # @param reason [String] The reason the for the creation of this invite.
    # @return [Invite] the created invite.
    def make_invite(max_age = 0, max_uses = 0, temporary = false, unique = false, reason = nil)
      response = API::Channel.create_invite(@bot.token, @id, max_age, max_uses, temporary, unique, reason)
      Invite.new(JSON.parse(response), @bot)
    end

    alias_method :invite, :make_invite

    # Starts typing, which displays the typing indicator on the client for five seconds.
    # If you want to keep typing you'll have to resend this every five seconds. (An abstraction
    # for this will eventually be coming)
    # @example Send a typing indicator for the bot in a given channel.
    #   channel.start_typing()
    def start_typing
      API::Channel.start_typing(@bot.token, @id)
    end

    # Creates a Group channel
    # @param user_ids [Array<Integer>] Array of user IDs to add to the new group channel (Excluding
    #   the recipient of the PM channel).
    # @return [Channel] the created channel.
    def create_group(user_ids)
      raise 'Attempted to create group channel on a non-pm channel!' unless pm?

      response = API::Channel.create_group(@bot.token, @id, user_ids.shift)
      channel = Channel.new(JSON.parse(response), @bot)
      channel.add_group_users(user_ids)
    end

    # Adds a user to a group channel.
    # @param user_ids [Array<String, Integer>, String, Integer] User ID or array of user IDs to add to the group channel.
    # @return [Channel] the group channel.
    def add_group_users(user_ids)
      raise 'Attempted to add a user to a non-group channel!' unless group?

      user_ids = [user_ids] unless user_ids.is_a? Array
      user_ids.each do |user_id|
        API::Channel.add_group_user(@bot.token, @id, user_id.resolve_id)
      end
      self
    end

    alias_method :add_group_user, :add_group_users

    # Removes a user from a group channel.
    # @param user_ids [Array<String, Integer>, String, Integer] User ID or array of user IDs to remove from the group channel.
    # @return [Channel] the group channel.
    def remove_group_users(user_ids)
      raise 'Attempted to remove a user from a non-group channel!' unless group?

      user_ids = [user_ids] unless user_ids.is_a? Array
      user_ids.each do |user_id|
        API::Channel.remove_group_user(@bot.token, @id, user_id.resolve_id)
      end
      self
    end

    alias_method :remove_group_user, :remove_group_users

    # Leaves the group.
    def leave_group
      raise 'Attempted to leave a non-group channel!' unless group?

      API::Channel.leave_group(@bot.token, @id)
    end

    alias_method :leave, :leave_group

    # Creates a webhook in this channel
    # @param name [String] the default name of this webhook.
    # @param avatar [String] the default avatar URL to give this webhook.
    # @param reason [String] the reason for the webhook creation.
    # @raise [ArgumentError] if the channel isn't a text channel in a server.
    # @return [Webhook] the created webhook.
    def create_webhook(name, avatar = nil, reason = nil)
      raise ArgumentError, 'Tried to create a webhook in a non-server channel' unless server
      raise ArgumentError, 'Tried to create a webhook in a non-text channel' unless text?

      response = API::Channel.create_webhook(@bot.token, @id, name, avatar, reason)
      Webhook.new(JSON.parse(response), @bot)
    end

    # Requests a list of Webhooks on the channel.
    # @return [Array<Webhook>] webhooks on the channel.
    def webhooks
      raise 'Tried to request webhooks from a non-server channel' unless server

      webhooks = JSON.parse(API::Channel.webhooks(@bot.token, @id))
      webhooks.map { |webhook_data| Webhook.new(webhook_data, @bot) }
    end

    # Requests a list of Invites to the channel.
    # @return [Array<Invite>] invites to the channel.
    def invites
      raise 'Tried to request invites from a non-server channel' unless server

      invites = JSON.parse(API::Channel.invites(@bot.token, @id))
      invites.map { |invite_data| Invite.new(invite_data, @bot) }
    end

    # The default `inspect` method is overwritten to give more useful output.
    def inspect
      "<Channel name=#{@name} id=#{@id} topic=\"#{@topic}\" type=#{@type} position=#{@position} server=#{@server}>"
    end

    # Adds a recipient to a group channel.
    # @param recipient [Recipient] the recipient to add to the group
    # @raise [ArgumentError] if tried to add a non-recipient
    # @note For internal use only
    # @!visibility private
    def add_recipient(recipient)
      raise 'Tried to add recipient to a non-group channel' unless group?
      raise ArgumentError, 'Tried to add a non-recipient to a group' unless recipient.is_a?(Recipient)

      @recipients << recipient
    end

    # Removes a recipient from a group channel.
    # @param recipient [Recipient] the recipient to remove from the group
    # @raise [ArgumentError] if tried to remove a non-recipient
    # @note For internal use only
    # @!visibility private
    def remove_recipient(recipient)
      raise 'Tried to remove recipient from a non-group channel' unless group?
      raise ArgumentError, 'Tried to remove a non-recipient from a group' unless recipient.is_a?(Recipient)

      @recipients.delete(recipient)
    end

    # Updates the cached data with new data
    # @note For internal use only
    # @!visibility private
    def update_data(new_data = nil)
      new_data ||= JSON.parse(API::Channel.resolve(@bot.token, @id))
      @name = new_data[:name] || new_data['name'] || @name
      @topic = new_data[:topic] || new_data['topic'] || @topic
      @position = new_data[:position] || new_data['position'] || @position
      @bitrate = new_data[:bitrate] || new_data['bitrate'] || @bitrate
      @user_limit = new_data[:user_limit] || new_data['user_limit'] || @user_limit
      new_nsfw = new_data.key?(:nsfw) ? new_data[:nsfw] : new_data['nsfw']
      @nsfw = new_nsfw.nil? ? @nsfw : new_nsfw
      @parent_id = new_data[:parent_id] || new_data['parent_id'] || @parent_id
      process_permission_overwrites(new_data[:permission_overwrites] || new_data['permission_overwrites'])
      @rate_limit_per_user = new_data[:rate_limit_per_user] || new_data['rate_limit_per_user'] || @rate_limit_per_user
    end

    # @return [String] a URL that a user can use to navigate to this channel in the client
    def link
      "https://discord.com/channels/#{@server&.id || '@me'}/#{@channel.id}"
    end

    alias_method :jump_link, :link

    private

    # For bulk_delete checking
    TWO_WEEKS = 86_400 * 14

    # Deletes a list of messages on this channel using bulk delete.
    def bulk_delete(ids, strict = false, reason = nil)
      min_snowflake = IDObject.synthesise(Time.now - TWO_WEEKS)

      ids.reject! do |e|
        next unless e < min_snowflake

        message = "Attempted to bulk_delete message #{e} which is too old (min = #{min_snowflake})"
        raise ArgumentError, message if strict

        Discordrb::LOGGER.warn(message)
        true
      end

      API::Channel.bulk_delete_messages(@bot.token, @id, ids, reason)
      ids.size
    end

    def update_channel_data(new_data)
      new_nsfw = new_data[:nsfw].is_a?(TrueClass) || new_data[:nsfw].is_a?(FalseClass) ? new_data[:nsfw] : @nsfw
      # send permission_overwrite only when explicitly set
      overwrites = new_data[:permission_overwrites] ? new_data[:permission_overwrites].map { |_, v| v.to_hash } : nil
      response = JSON.parse(API::Channel.update(@bot.token, @id,
                                                new_data[:name] || @name,
                                                new_data[:topic] || @topic,
                                                new_data[:position] || @position,
                                                new_data[:bitrate] || @bitrate,
                                                new_data[:user_limit] || @user_limit,
                                                new_nsfw,
                                                overwrites,
                                                new_data[:parent_id] || @parent_id,
                                                new_data[:rate_limit_per_user] || @rate_limit_per_user))
      update_data(response)
    end

    def process_permission_overwrites(overwrites)
      # Populate permission overwrites
      @permission_overwrites = {}
      return unless overwrites

      overwrites.each do |element|
        id = element['id'].to_i
        @permission_overwrites[id] = Overwrite.from_hash(element)
      end
    end
  end
end
