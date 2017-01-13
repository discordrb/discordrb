module Helpers
  SERVER_ID = 1
  SERVER_NAME = 'server_name'.freeze
  EMOJI1_ID = 10
  EMOJI1_NAME = 'emoji_name_1'.freeze
  EMOJI2_ID = 11
  EMOJI2_NAME = 'emoji_name_2'.freeze
  EMOJI3_ID = 12
  EMOJI3_NAME = 'emoji_name_3'.freeze

  def help
    :available
  end

  def fake_emoji_data
    JSON.parse(%({"guild_id":#{SERVER_ID}, "emojis": [{"roles":[],"require_colons":true,"name":"#{EMOJI1_NAME}","managed":false,"id":"#{EMOJI1_ID}"}, {"roles":[],"require_colons":true,"name":"#{EMOJI2_NAME}","managed":false,"id":"#{EMOJI2_ID}"}] }))
  end

  def fake_server_data
    JSON.parse(%({ "verification_level": 0, "features": [], "emojis": [{"roles":[],"require_colons":true,"name":"#{EMOJI1_NAME}","managed":false,"id":"#{EMOJI1_ID}"}, {"roles":[],"require_colons":true,"name":"#{EMOJI2_NAME}","managed":false,"id":"#{EMOJI2_ID}"}] }))
  end
end
