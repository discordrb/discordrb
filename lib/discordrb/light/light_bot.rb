# frozen_string_literal: true

# This module contains classes to allow connections to bots without a connection to the gateway socket, i. e. bots
# that only use the REST part of the API.
module Discordrb::Light
  # A bot that only uses the REST part of the API. Hierarchically unrelated to the regular {Discordrb::Bot}. Useful to
  # make applications integrated to Discord over OAuth, for example.
  class LightBot
  end
end
