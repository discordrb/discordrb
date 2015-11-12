require 'discordrb/version'
require 'discordrb/bot'
require 'discordrb/commands/command_bot'

# All discordrb functionality, to be extended by other files
module Discordrb
  # Simple Levenshtein distance (slow)
  def levenshtein(one, two)
    return two.size if one.size == 0
    return one.size if two.size == 0

    [levenshtein(one.chop, two) + 1,
     levenshtein(one, two.chop) + 1,
     levenshtein(one.chop, two.chop) + (one[-1, 1] == two[-1, 1] ? 0 : 1)].min
  end
end
