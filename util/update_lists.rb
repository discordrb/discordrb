require 'open-uri'
require 'json'

# Thanks to abalabahaha for hosting this continually-updating version of the Discord games list.
GAMES_LIST_URL = 'https://abal.moe/Discord/JSON/games.json'
GAMES_LIST_FILE_PATH = 'lib/discordrb/games_list.rb'

raw_json = open(GAMES_LIST_URL).read
puts "Loaded #{raw_json.length} bytes from #{GAMES_LIST_URL}"

parsed = JSON.parse(raw_json)
puts "Loaded #{parsed.length} games"

list = "module Discordrb::Games
  @raw_games = #{parsed}
end
"

File.write(GAMES_LIST_FILE_PATH, list)
puts "Successfully wrote games list to #{GAMES_LIST_FILE_PATH}"
