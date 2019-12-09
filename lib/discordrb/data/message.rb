# frozen_string_literal: true

module Discordrb
  # A message on Discord that was sent to a text channel
  class Message
    include IDObject

    # @return [String] the content of this message.
    attr_reader :content
    alias_method :text, :content
    alias_method :to_s, :content

    # @return [Member, User] the user that sent this message. (Will be a {Member} most of the time, it should only be a
    #   {User} for old messages when the author has left the server since then)
    attr_reader :author
    alias_method :user, :author
    alias_method :writer, :author

    # @return [Channel] the channel in which this message was sent.
    attr_reader :channel

    # @return [Time] the timestamp at which this message was sent.
    attr_reader :timestamp

    # @return [Time] the timestamp at which this message was edited. `nil` if the message was never edited.
    attr_reader :edited_timestamp
    alias_method :edit_timestamp, :edited_timestamp

    # @return [Array<User>] the users that were mentioned in this message.
    attr_reader :mentions

    # @return [Array<Role>] the roles that were mentioned in this message.
    attr_reader :role_mentions

    # @return [Array<Attachment>] the files attached to this message.
    attr_reader :attachments

    # @return [Array<Embed>] the embed objects contained in this message.
    attr_reader :embeds

    # @return [Array<Reaction>] the reaction objects contained in this message.
    attr_reader :reactions

    # @return [true, false] whether the message used Text-To-Speech (TTS) or not.
    attr_reader :tts
    alias_method :tts?, :tts

    # @return [String] used for validating a message was sent.
    attr_reader :nonce

    # @return [true, false] whether the message was edited or not.
    attr_reader :edited
    alias_method :edited?, :edited

    # @return [true, false] whether the message mentioned everyone or not.
    attr_reader :mention_everyone
    alias_method :mention_everyone?, :mention_everyone
    alias_method :mentions_everyone?, :mention_everyone

    # @return [true, false] whether the message is pinned or not.
    attr_reader :pinned
    alias_method :pinned?, :pinned

    # @return [Server, nil] the server in which this message was sent.
    attr_reader :server

    # @return [Integer, nil] the webhook ID that sent this message, or `nil` if it wasn't sent through a webhook.
    attr_reader :webhook_id

    # The discriminator that webhook user accounts have.
    ZERO_DISCRIM = '0000'

    # @!visibility private
    def initialize(data, bot)
      @bot = bot
      @content = data['content']
      @channel = bot.channel(data['channel_id'].to_i)
      @pinned = data['pinned']
      @tts = data['tts']
      @nonce = data['nonce']
      @mention_everyone = data['mention_everyone']

      @server = bot.server(data['guild_id'].to_i) if data['guild_id']

      @author = if data['author']
                  if data['author']['discriminator'] == ZERO_DISCRIM
                    # This is a webhook user! It would be pointless to try to resolve a member here, so we just create
                    # a User and return that instead.
                    Discordrb::LOGGER.debug("Webhook user: #{data['author']['id']}")
                    User.new(data['author'], @bot)
                  elsif @channel.private?
                    # Turn the message user into a recipient - we can't use the channel recipient
                    # directly because the bot may also send messages to the channel
                    Recipient.new(bot.user(data['author']['id'].to_i), @channel, bot)
                  else
                    member = @channel.server.member(data['author']['id'].to_i)

                    unless member
                      Discordrb::LOGGER.debug("Member with ID #{data['author']['id']} not cached (possibly left the server).")
                      member = @bot.ensure_user(data['author'])
                    end

                    member
                  end
                end

      @webhook_id = data['webhook_id'].to_i if data['webhook_id']

      @timestamp = Time.parse(data['timestamp']) if data['timestamp']
      @edited_timestamp = data['edited_timestamp'].nil? ? nil : Time.parse(data['edited_timestamp'])
      @edited = !@edited_timestamp.nil?
      @id = data['id'].to_i

      @emoji = []

      @reactions = []

      data['reactions']&.each do |element|
        @reactions << Reaction.new(element)
      end

      @mentions = []

      data['mentions']&.each do |element|
        @mentions << bot.ensure_user(element)
      end

      @role_mentions = []

      # Role mentions can only happen on public servers so make sure we only parse them there
      if @channel.text?
        data['mention_roles']&.each do |element|
          @role_mentions << @channel.server.role(element.to_i)
        end
      end

      @attachments = []
      @attachments = data['attachments'].map { |e| Attachment.new(e, self, @bot) } if data['attachments']

      @embeds = []
      @embeds = data['embeds'].map { |e| Embed.new(e, self) } if data['embeds']
    end

    # Replies to this message with the specified content.
    # @see Channel#send_message
    def reply(content)
      @channel.send_message(content)
    end

    # Edits this message to have the specified content instead.
    # You can only edit your own messages.
    # @param new_content [String] the new content the message should have.
    # @param new_embed [Hash, Discordrb::Webhooks::Embed, nil] The new embed the message should have. If `nil` the message will be changed to have no embed.
    # @return [Message] the resulting message.
    def edit(new_content, new_embed = nil)
      response = API::Channel.edit_message(@bot.token, @channel.id, @id, new_content, [], new_embed ? new_embed.to_hash : nil)
      Message.new(JSON.parse(response), @bot)
    end

    # Deletes this message.
    def delete(reason = nil)
      API::Channel.delete_message(@bot.token, @channel.id, @id, reason)
      nil
    end

    # Pins this message
    def pin(reason = nil)
      API::Channel.pin_message(@bot.token, @channel.id, @id, reason)
      @pinned = true
      nil
    end

    # Unpins this message
    def unpin(reason = nil)
      API::Channel.unpin_message(@bot.token, @channel.id, @id, reason)
      @pinned = false
      nil
    end

    # Add an {Await} for a message with the same user and channel.
    # @see Bot#add_await
    # @deprecated Will be changed to blocking behavior in v4.0. Use {#await!} instead.
    def await(key, attributes = {}, &block)
      @bot.add_await(key, Discordrb::Events::MessageEvent, { from: @author.id, in: @channel.id }.merge(attributes), &block)
    end

    # Add a blocking {Await} for a message with the same user and channel.
    # @see Bot#add_await!
    def await!(attributes = {}, &block)
      @bot.add_await!(Discordrb::Events::MessageEvent, { from: @author.id, in: @channel.id }.merge(attributes), &block)
    end

    # @return [true, false] whether this message was sent by the current {Bot}.
    def from_bot?
      @author&.current_bot?
    end

    # @return [true, false] whether this message has been sent over a webhook.
    def webhook?
      !@webhook_id.nil?
    end

    # @!visibility private
    # @return [Array<String>] the emoji mentions found in the message
    def scan_for_emoji
      emoji = @content.split
      emoji = emoji.grep(/<(?<animated>a)?:(?<name>\w+):(?<id>\d+)>?/)
      emoji
    end

    # @return [Array<Emoji>] the emotes that were used/mentioned in this message.
    def emoji
      return if @content.nil?

      emoji = scan_for_emoji
      emoji.each do |element|
        @emoji << @bot.parse_mention(element)
      end
      @emoji
    end

    # Check if any emoji were used in this message.
    # @return [true, false] whether or not any emoji were used
    def emoji?
      emoji = scan_for_emoji
      return true unless emoji.empty?
    end

    # Check if any reactions were used in this message.
    # @return [true, false] whether or not this message has reactions
    def reactions?
      @reactions.empty?
    end

    # Returns the reactions made by the current bot or user.
    # @return [Array<Reaction>] the reactions
    def my_reactions
      @reactions.select(&:me)
    end

    # Reacts to a message.
    # @param reaction [String, #to_reaction] the unicode emoji or {Emoji}
    def create_reaction(reaction)
      reaction = reaction.to_reaction if reaction.respond_to?(:to_reaction)
      API::Channel.create_reaction(@bot.token, @channel.id, @id, reaction)
      nil
    end

    alias_method :react, :create_reaction

    # Returns the list of users who reacted with a certain reaction.
    # @param reaction [String, #to_reaction] the unicode emoji or {Emoji}
    # @param limit [Integer] the limit of how many users to retrieve. `nil` will return all users
    # @example Get all the users that reacted with a thumbsup.
    #   thumbs_up_reactions = message.reacted_with("\u{1F44D}")
    # @return [Array<User>] the users who used this reaction
    def reacted_with(reaction, limit: 100)
      reaction = reaction.to_reaction if reaction.respond_to?(:to_reaction)
      paginator = Paginator.new(limit, :down) do |last_page|
        after_id = last_page.last.id if last_page
        last_page = JSON.parse(API::Channel.get_reactions(@bot.token, @channel.id, @id, reaction, nil, after_id, limit))
        last_page.map { |d| User.new(d, @bot) }
      end
      paginator.to_a
    end

    # Deletes a reaction made by a user on this message.
    # @param user [User, String, Integer] the user or user ID who used this reaction
    # @param reaction [String, #to_reaction] the reaction to remove
    def delete_reaction(user, reaction)
      reaction = reaction.to_reaction if reaction.respond_to?(:to_reaction)
      API::Channel.delete_user_reaction(@bot.token, @channel.id, @id, reaction, user.resolve_id)
    end

    # Deletes this client's reaction on this message.
    # @param reaction [String, #to_reaction] the reaction to remove
    def delete_own_reaction(reaction)
      reaction = reaction.to_reaction if reaction.respond_to?(:to_reaction)
      API::Channel.delete_own_reaction(@bot.token, @channel.id, @id, reaction)
    end

    # Removes all reactions from this message.
    def delete_all_reactions
      API::Channel.delete_all_reactions(@bot.token, @channel.id, @id)
    end

    # The inspect method is overwritten to give more useful output
    def inspect
      "<Message content=\"#{@content}\" id=#{@id} timestamp=#{@timestamp} author=#{@author} channel=#{@channel}>"
    end
  end
end
