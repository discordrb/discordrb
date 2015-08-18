module Discordrb::Endpoints
  BASE = "https://discordapp.com/"
  APIBASE = BASE + "api"

  WEBSOCKET_HUB = "wss://discordapp.com/hub"

  LOGIN = APIBASE + "/auth/login"
  LOGOUT = APIBASE + "/auth/logout"

  SERVERS = APIBASE + "/guilds"

  CHANNELS = APIBASE + "/channels"
end
