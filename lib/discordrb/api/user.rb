# API calls for User object
module Discordrb::API::User
  module_function

  # Make an avatar URL from the user and avatar IDs
  def avatar_url(user_id, avatar_id)
    "#{Discordrb::API.api_base}/users/#{user_id}/avatars/#{avatar_id}.jpg"
  end
end
