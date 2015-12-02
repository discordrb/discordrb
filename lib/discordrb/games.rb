require 'discordrb/games_list'

# The "Game" class and a list of games
module Discordrb::Games
  # A game Discord uses in the "Playing game" status
  class Game
    attr_reader :id, :name, :executables

    def initialize(hash)
      @id = hash[:id] || hash['id']
      @name = hash[:name] || hash['name']
      @executables = hash[:executables] || hash['executables']
    end
  end

  @games = @raw_games.map do |hash|
    Game.new(hash)
  end

  module_function

  attr_reader :games

  def find_game(name_or_id)
    return name_or_id if name_or_id.is_a? Game
    @games.each do |game|
      return game if game.name == name_or_id || game.id == name_or_id || game.id.to_s == name_or_id
    end
    nil
  end
end
