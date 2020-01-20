# frozen_string_literal: true

module Discordrb
  # A server's audit logs
  class AuditLogs
    # The numbers associated with the type of action.
    ACTIONS = {
      1 => :server_update,
      10 => :channel_create,
      11 => :channel_update,
      12 => :channel_delete,
      13 => :channel_overwrite_create,
      14 => :channel_overwrite_update,
      15 => :channel_overwrite_delete,
      20 => :member_kick,
      21 => :member_prune,
      22 => :member_ban_add,
      23 => :member_ban_remove,
      24 => :member_update,
      25 => :member_role_update,
      26 => :member_move,
      27 => :member_disconnect,
      28 => :bot_add,
      30 => :role_create,
      31 => :role_update,
      32 => :role_delete,
      40 => :invite_create,
      41 => :invite_update,
      42 => :invite_delete,
      50 => :webhook_create,
      51 => :webhook_update,
      52 => :webhook_delete,
      60 => :emoji_create,
      61 => :emoji_update,
      62 => :emoji_delete,
      # 70
      # 71
      72 => :message_delete,
      73 => :message_bulk_delete,
      74 => :message_pin,
      75 => :message_unpin,
      80 => :integration_create,
      81 => :integration_update,
      82 => :integration_delete
    }.freeze

    # @!visibility private
    CREATE_ACTIONS = %i[
      channel_create channel_overwrite_create member_ban_add role_create
      invite_create webhook_create emoji_create integration_create
    ].freeze

    # @!visibility private
    DELETE_ACTIONS = %i[
      channel_delete channel_overwrite_delete member_kick member_prune
      member_ban_remove role_delete invite_delete webhook_delete
      emoji_delete message_delete message_bulk_delete integration_delete
    ].freeze

    # @!visibility private
    UPDATE_ACTIONS = %i[
      server_update channel_update channel_overwrite_update member_update
      member_role_update role_update invite_update webhook_update
      emoji_update integration_update
    ].freeze

    # @return [Hash<String => User>] the users included in the audit logs.
    attr_reader :users

    # @return [Hash<String => Webhook>] the webhooks included in the audit logs.
    attr_reader :webhooks

    # @return [Array<Entry>] the entries listed in the audit logs.
    attr_reader :entries

    # @!visibility private
    def initialize(server, bot, data)
      @bot = bot
      @server = server
      @users = {}
      @webhooks = {}
      @entries = data['audit_log_entries'].map { |entry| Entry.new(self, @server, @bot, entry) }

      process_users(data['users'])
      process_webhooks(data['webhooks'])
    end

    # An entry in a server's audit logs.
    class Entry
      include IDObject

      # @return [Symbol] the action that was performed.
      attr_reader :action

      # @return [Symbol] the type action that was performed. (:create, :delete, :update, :unknown)
      attr_reader :action_type

      # @return [Symbol] the type of target being performed on. (:server, :channel, :user, :role, :invite, :webhook, :emoji, :unknown)
      attr_reader :target_type

      # @return [Integer, nil] the amount of messages deleted. Only present if the action is `:message_delete`.
      attr_reader :count
      alias_method :amount, :count

      # @return [Integer, nil] the amount of days the members were inactive for. Only present if the action is `:member_prune`.
      attr_reader :days

      # @return [Integer, nil] the amount of members removed. Only present if the action is `:member_prune`.
      attr_reader :members_removed

      # @return [String, nil] the reason for this action occurring.
      attr_reader :reason

      # @return [Hash<String => Change>, RoleChange, nil] the changes from this log, listing the key as the key changed. Will be a RoleChange object if the action is `:member_role_update`. Will be nil if the action is either `:message_delete` or `:member_prune`.
      attr_reader :changes

      # @!visibility private
      def initialize(logs, server, bot, data)
        @bot = bot
        @id = data['id'].resolve_id
        @logs = logs
        @server = server
        @data = data
        @action = ACTIONS[data['action_type']]
        @reason = data['reason']
        @action_type = AuditLogs.action_type_for(data['action_type'])
        @target_type = AuditLogs.target_type_for(data['action_type'])

        # Sets the 'changes' variable to a empty hash if there are no special actions.
        @changes = {} unless @action == :message_delete || @action == :member_prune || @action == :member_role_update

        # Sets the 'changes' variable to a RoleChange class if there's a role update.
        @changes = RoleChange.new(data['changes'][0], @server) if @action == :member_role_update

        process_changes(data['changes']) unless @action == :member_role_update
        return unless data.include?('options')

        # Checks and sets variables for special action options.
        @count = data['options']['count'].to_i unless data['options']['count'].nil?
        @channel_id = data['options']['channel'].to_i unless data['options']['channel'].nil?
        @days = data['options']['delete_member_days'].to_i unless data['options']['delete_member_days'].nil?
        @members_removed = data['options']['members_removed'].to_i unless data['options']['members_removed'].nil?
      end

      # @return [Server, Channel, Member, User, Role, Invite, Webhook, Emoji, nil] the target being performed on.
      def target
        @target ||= process_target(@data['target_id'], @target_type)
      end

      # @return [Member, User] the user that authored this action. Can be a User object if the user no longer exists in the server.
      def user
        @user ||= @server.member(@data['user_id'].to_i) || @bot.user(@data['user_id'].to_i) || @logs.user(@data['user_id'].to_i)
      end
      alias_method :author, :user

      # @return [Channel, nil] the amount of messages deleted. Won't be nil if the action is `:message_delete`.
      def channel
        return nil unless @channel_id

        @channel ||= @bot.channel(@channel_id, @server, bot, self)
      end

      # @!visibility private
      def process_target(id, type)
        id = id.resolve_id unless id.nil?
        case type
        when :server then @server # Since it won't be anything else
        when :channel then @bot.channel(id, @server)
        when :user, :message then @server.member(id) || @bot.user(id) || @logs.user(id)
        when :role then @server.role(id)
        when :invite then @bot.invite(@data['changes'].find { |change| change['key'] == 'code' }.values.delete_if { |v| v == 'code' }.first)
        when :webhook then @server.webhooks.find { |webhook| webhook.id == id } || @logs.webhook(id)
        when :emoji then @server.emoji[id]
        when :integration then @server.integrations.find { |integration| integration.id == id }
        end
      end

      # The inspect method is overwritten to give more useful output
      def inspect
        "<AuditLogs::Entry id=#{@id} action=#{@action} reason=#{@reason} action_type=#{@action_type} target_type=#{@target_type} count=#{@count} days=#{@days} members_removed=#{@members_removed}>"
      end

      # Process action changes
      # @note For internal use only
      # @!visibility private
      def process_changes(changes)
        return unless changes

        changes.each do |element|
          change = Change.new(element, @server, @bot, self)
          @changes[change.key] = change
        end
      end
    end

    # A change in a audit log entry.
    class Change
      # @return [String] the key that was changed.
      # @note You should check with the Discord API Documentation on what key gives out what value.
      attr_reader :key

      # @return [String, Integer, true, false, Permissions, Overwrite, nil] the value that was changed from.
      attr_reader :old
      alias_method :old_value, :old

      # @return [String, Integer, true, false, Permissions, Overwrite, nil] the value that was changed to.
      attr_reader :new
      alias_method :new_value, :new

      # @!visibility private
      def initialize(data, server, bot, logs)
        @key = data['key']
        @old = data['old_value']
        @new = data['new_value']
        @server = server
        @bot = bot
        @logs = logs

        @old = Permissions.new(@old) if @old && @key == 'permissions'
        @new = Permissions.new(@new) if @new && @key == 'permissions'

        @old = @old.map { |o| Overwrite.new(o['id'], type: o['type'].to_sym, allow: o['allow'], deny: o['deny']) } if @old && @key == 'permission_overwrites'
        @new = @new.map { |o| Overwrite.new(o['id'], type: o['type'].to_sym, allow: o['allow'], deny: o['deny']) } if @new && @key == 'permission_overwrites'
      end

      # @return [Channel, nil] the channel that was previously used in the server widget. Only present if the key for this change is `widget_channel_id`.
      def old_widget_channel
        @bot.channel(@old, @server) if @old && @key == 'widget_channel_id'
      end

      # @return [Channel, nil] the channel that is used in the server widget prior to this change. Only present if the key for this change is `widget_channel_id`.
      def new_widget_channel
        @bot.channel(@new, @server) if @new && @key == 'widget_channel_id'
      end

      # @return [Channel, nil] the channel that was previously used in the server as an AFK channel. Only present if the key for this change is `afk_channel_id`.
      def old_afk_channel
        @bot.channel(@old, @server) if @old && @key == 'afk_channel_id'
      end

      # @return [Channel, nil] the channel that is used in the server as an AFK channel prior to this change. Only present if the key for this change is `afk_channel_id`.
      def new_afk_channel
        @bot.channel(@new, @server) if @new && @key == 'afk_channel_id'
      end

      # @return [Member, User, nil] the member that used to be the owner of the server. Only present if the for key for this change is `owner_id`.
      def old_owner
        @server.member(@old) || @bot.user(@old) || @logs.user(@old) if @old && @key == 'owner_id'
      end

      # @return [Member, User, nil] the member that is now the owner of the server prior to this change. Only present if the key for this change is `owner_id`.
      def new_owner
        @server.member(@new) || @bot.user(@new) || @logs.user(@new) if @new && @key == 'owner_id'
      end
    end

    # A change that includes roles.
    class RoleChange
      # @return [Symbol] what type of change this is: (:add, :remove)
      attr_reader :type

      # @!visibility private
      def initialize(data, server)
        @type = data['key'].delete('$').to_sym
        @role_id = data['new_value'][0]['id'].to_i
        @server = server
      end

      # @return [Role] the role being used.
      def role
        @role ||= @server.role(@role_id)
      end
    end

    # @return [Entry] the latest entry in the audit logs.
    def latest
      @entries.first
    end
    alias_method :first, :latest

    # Gets a user in the audit logs data based on user ID
    # @note This only uses data given by the audit logs request
    # @param id [String, Integer] The user ID to look for
    def user(id)
      @users[id.resolve_id]
    end

    # Gets a webhook in the audit logs data based on webhook ID
    # @note This only uses data given by the audit logs request
    # @param id [String, Integer] The webhook ID to look for
    def webhook(id)
      @webhooks[id.resolve_id]
    end

    # Process user objects given by the request
    # @note For internal use only
    # @!visibility private
    def process_users(users)
      users.each do |element|
        user = User.new(element, @bot)
        @users[user.id] = user
      end
    end

    # Process webhook objects given by the request
    # @note For internal use only
    # @!visibility private
    def process_webhooks(webhooks)
      webhooks.each do |element|
        webhook = Webhook.new(element, @bot)
        @webhooks[webhook.id] = webhook
      end
    end

    # Find the type of target by it's action number
    # @note For internal use only
    # @!visibility private
    def self.target_type_for(action)
      case action
      when 1..9 then :server
      when 10..19 then :channel
      when 20..29 then :user
      when 30..39 then :role
      when 40..49 then :invite
      when 50..59 then :webhook
      when 60..69 then :emoji
      when 70..79 then :message
      when 80..89 then :integration
      else :unknown
      end
    end

    # Find the type of action by its action number
    # @note For internal use only
    # @!visibility private
    def self.action_type_for(action)
      action = ACTIONS[action]
      return :create if CREATE_ACTIONS.include?(action)
      return :delete if DELETE_ACTIONS.include?(action)
      return :update if UPDATE_ACTIONS.include?(action)

      :unknown
    end
  end
end
