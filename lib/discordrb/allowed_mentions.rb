# frozen_string_literal: true

require 'discordrb/id_object'

module Discordrb
  # Builder class for `allowed_mentions` when sending messages.
  class AllowedMentions
    # @return [Array<"users", "roles", "everyone">, nil]
    attr_accessor :parse

    # @return [Array<String, Integer>, nil]
    attr_accessor :users

    # @return [Array<String, Integer>, nil]
    attr_accessor :roles

    # @param parse [Array<"users", "roles", "everyone">] Mention types that can be inferred from the message.
    #   `users` and `roles` allow for all mentions of the respective type to ping. `everyone` allows usage of `@everyone` and `@here`
    # @param users [Array<User, String, Integer>] Users or user IDs that can be pinged. Cannot be used in conjunction with `"users"` in `parse`
    # @param roles [Array<Role, String, Integer>] Roles or role IDs that can be pinged. Cannot be used in conjunction with `"roles"` in `parse`
    def initialize(parse: nil, users: nil, roles: nil)
      @parse = parse
      @users = users
      @roles = roles
    end

    # @!visibility private
    def to_hash
      {
        parse: @parse,
        users: @users&.map { |user| user.is_a?(IDObject) ? user.id : user },
        roles: @roles&.map { |role| role.is_a?(IDObject) ? role.id : role }
      }.compact
    end
  end
end
