# frozen_string_literal: true

module Discordrb
  # This class is a special variant of User that represents the bot's user profile (things like own username and the avatar).
  # It can be accessed using {Bot#profile}.
  class Profile < User
    # Whether or not the user is the bot. The Profile can only ever be the bot user, so this always returns true.
    # @return [true]
    def current_bot?
      true
    end

    # Sets the bot's username.
    # @param username [String] The new username.
    def username=(username)
      update_profile_data(username: username)
    end

    alias_method :name=, :username=

    # Changes the bot's avatar.
    # @param avatar [String, #read] A JPG file to be used as the avatar, either
    #  something readable (e.g. File Object) or as a data URL.
    def avatar=(avatar)
      if avatar.respond_to? :read
        # Set the file to binary mode if supported, so we don't get problems with Windows
        avatar.binmode if avatar.respond_to?(:binmode)

        avatar_string = 'data:image/jpg;base64,'
        avatar_string += Base64.strict_encode64(avatar.read)
        update_profile_data(avatar: avatar_string)
      else
        update_profile_data(avatar: avatar)
      end
    end

    # Updates the cached profile data with the new one.
    # @note For internal use only.
    # @!visibility private
    def update_data(new_data)
      @username = new_data[:username] || @username
      @avatar_id = new_data[:avatar_id] || @avatar_id
    end

    # Sets the user status setting to Online.
    # @note Only usable on User accounts.
    def online
      update_profile_status_setting('online')
    end

    # Sets the user status setting to Idle.
    # @note Only usable on User accounts.
    def idle
      update_profile_status_setting('idle')
    end

    # Sets the user status setting to Do Not Disturb.
    # @note Only usable on User accounts.
    def dnd
      update_profile_status_setting('dnd')
    end

    alias_method(:busy, :dnd)

    # Sets the user status setting to Invisible.
    # @note Only usable on User accounts.
    def invisible
      update_profile_status_setting('invisible')
    end

    # The inspect method is overwritten to give more useful output
    def inspect
      "<Profile user=#{super}>"
    end

    private

    # Internal handler for updating the user's status setting
    def update_profile_status_setting(status)
      API::User.change_status_setting(@bot.token, status)
    end

    def update_profile_data(new_data)
      API::User.update_profile(@bot.token,
                               nil, nil,
                               new_data[:username] || @username,
                               new_data.key?(:avatar) ? new_data[:avatar] : @avatar_id)
      update_data(new_data)
    end
  end
end
