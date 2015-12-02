require 'discordrb/games'

describe Discordrb::Games do
  describe Discordrb::Games::Game do
    it 'should initialize without errors' do
      hash = {
        id: 123,
        name: 'Pokémon Super Mystery Dungeon',
        executables: []
      }

      Discordrb::Games::Game.new(hash)
    end

    it 'should contain the given values' do
      hash = {
        id: 123,
        name: 'Pokémon Super Mystery Dungeon',
        executables: []
      }

      game = Discordrb::Games::Game.new(hash)
      game.id.should eq(123)
      game.name.should eq('Pokémon Super Mystery Dungeon')
      game.executables.should eq([])
    end
  end

  it 'should contain FFXI as the zeroth element' do
    game = Discordrb::Games.games[0]
    game.id.should eq(0)
    game.name.should eq('FINAL FANTASY XI')
  end

  describe 'find_game' do
    it 'should return a Game when it is given one' do
      hash = {
        id: 123,
        name: 'Pokémon Super Mystery Dungeon',
        executables: []
      }

      game = Discordrb::Games::Game.new(hash)
      game.should be(Discordrb::Games.find_game(game))
    end

    it 'should find a game by name' do
      game = Discordrb::Games.find_game('FINAL FANTASY XI')
      game.id.should eq(0)
      game.name.should eq('FINAL FANTASY XI')
    end

    it 'should find a game by ID' do
      game = Discordrb::Games.find_game(0)
      game.id.should eq(0)
      game.name.should eq('FINAL FANTASY XI')

      game = Discordrb::Games.find_game('0')
      game.id.should eq(0)
      game.name.should eq('FINAL FANTASY XI')
    end

    it 'should return nil if a game is not found' do
      Discordrb::Games.find_game('this game does not exist').should be(nil)
    end
  end
end
