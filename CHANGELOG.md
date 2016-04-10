# Changelog

## 2.0.2

- Added `Server#text_channels` and `#voice_channels` ([#79](https://github.com/meew0/discordrb/issues/79))
- Added `Server#online_users` ([#80](https://github.com/meew0/discordrb/issues/80))
- Added `Member#role?` ([#83](https://github.com/meew0/discordrb/issues/83))
- Added three utility methods `User#online?`, `#offline?`, and `#idle?`
- `Bot#send_message` can now take channel objects as well as the ID

### Bugfixes

- Removing the bot from a server will no longer result in a gateway message error
- Fixed an exception raised if a previously unavailable guild goes online after the stream timeout
- `server_create` will no longer be raised for newly available guilds
- Fixed the annoying message about constant reassignment at startup
- Fixed an error where rarely a server's owner wouldn't be initialized correctly

## 2.0.1

- Added some more examples ([#75](https://github.com/meew0/discordrb/pull/75), thanks @greenbigfrog)
- Users can now be ignored from messages at gateway level (`Bot#ignore_user`, `Bot#unignore_user`)
- `Member#add_role` and `Member#remove_role` were re-added from User - they were missing before

### Bugfixes

- Fixed some typos in the documentation
- If a server is actually unavailable it will no longer spam the console with timeout messages
- VoiceBot now sends five frames of silence after finishing a track. This fixes an issue where the sound from the last track would bleed over into the new one due to interpolation.
- Fixed a bug where playing something right after connecting to voice would sometimes cause the encryption key to not be set

## 2.0.0

This is the first major update with some breaking changes! Those are highlighted in bold with migration advice after them. Ask in the Discord channel (see the README) if you have questions.

- **Bot initializers now only use named parameters.** This shouldn't be a hard change to adjust to, but everyone will have to do it. Here's some examples:
 ```rb
 # Previously
 bot = Discordrb::Bot.new 'email@example.com', 'hunter2', true

 # Now
 bot = Discordrb::Bot.new email: 'email@example.com', password: 'hunter2', log_mode: :debug
 ```
 ```rb
 # Previously
 bot = Discordrb::Bot.new :token, 'TOKEN HERE'

 # Now
 bot = Discordrb::Bot.new token: 'TOKEN HERE', application_id: 163456789123456789
 ```
 ```rb
 # Previously
 bot = Discordrb::Commands::CommandBot.new :token, 'TOKEN HERE', '!', nil, {advanced_functionality: false}

 # Now
 bot = Discordrb::Commands::CommandBot.new token: 'TOKEN HERE', application_id: 163456789123456789, prefix: '!', advanced_functionality: false
 ```
 - Connecting to multiple voice channels at once (only available with bot accounts) is now supported. **This means `bot.voice` now takes the server ID as the parameter**. For a seamless switch, the utility method `MessageEvent#voice` was added - simply replace `bot.voice` with `event.voice` in all instances.
 - **The `Member` and `Recipient` classes were split off from `User`**. Members are users on servers and recipients are partners in private messages. Since both are delegates to `User`, most things will work as before, but most notably roles were changed to no longer be by ID (for example, instead of `event.author.roles(event.server.id)`, you'd just use `event.author.roles` instead).
 - **All previously deprecated methods were removed.** This includes:
   - `Server#afk_channel_id=` (use `afk_channel=`, it works with the ID too)
   - `Channel#is_private` (use `private?` instead, it's more reliable with edge cases like Twitch subscriber-only channels)
   - `Bot#find` (use `find_channel` instead, it does the exact same thing without confusion with `find_user`)
 - **`Server` is now used instead of `Guild` in all external methods and classes.** Previously, all the events regarding roles and such were called `GuildRoleXYZEvent`, now they're all called `ServerRoleXYZEvent` for consistency with other attributes and methods.
 - **`advanced_functionality` is now disabled by default.** If you absolutely need it, you can easily re-enable it by just setting that parameter in the CommandBot initializer, but for most people that didn't need it this will fix some bugs with mentions in commands and such.
 - **`User#bot?` was renamed to `User#current_bot?`** with the addition of the `User#bot_account?` reader to check for bot account-ness (the "BOT" tag visible on Discord)
 - Member chunks will no longer automatically be requested on startup, but rather once they're actually needed (`event.server.members`). This is both a performance change (much faster startup for large bots especially) and an important API compliance one - this is what the Discord devs have requested.
 - Initial support for bots that have no WebSocket connection was started. This is useful for web apps that need to get information on something without having to run something in the background all the time. A tutorial on these will be coming soon, in the meantime, use this short example:
```rb
require 'discordrb'
require 'discordrb/light'

bot = Discordrb::Light::LightBot.new 'token here'
puts bot.profile.username
```
 - OAuth bot accounts are now better supported using a method `Bot#invite_url` to get a bot's invite URL and sending tokens using the new `Bot` prefix.
 - discordrb now fully uses [websocket-client-simple](https://github.com/shokai/websocket-client-simple) (a.k.a. WSCS) instead of Faye::WebSocket, this means that the annoying OpenSSL library thing won't have to be done anymore.
 - The new version of the Discord gateway (v4) is supported and used by default. This should bring more stability and possibly slight performance improvements.
 - Some older v3 features that weren't supported before are now:
   - Compressed ready packets (should decrease network overhead for very large bots)
 - Discord rate limits are now supported better - the client will never send a message if it knows it's going to be rate limited, instead it's going to wait for the correct time.
 - Requests will now automatically be retried if a 502 (cloudflare error) is received.
 - `MessageEditEvent`s now have a whole message instead of just the ID to allow for checking the content of edited messages.
 - `Message`s now have an `attachments` array with files attached to the message.
 - `ReadyEvent` and `DisconnectEvent` now have the bot as a readable attribute - useful for container-based bots that don't have a way to get them otherwise.
 - `Bot#find_channel` can now parse channel mentions and search for specific types of channels (text or voice).
 - `Server#create_channel` can now create voice channels.
 - A utility function `User#distinct` was added to get the distinct representation of a user (i.e. name + discrim, for example "meew0#9811")
 - The `User#discriminator` attribute now has more aliases (`#tag`, `#discord_tag`, `#discrim`)
 - `Permission` objects can now be created or set even without a role writer, useful to quickly get byte representations of permissions
 - Permission overwrites can now be defined more easily using the utility method `Channel#define_overwrite`
 - `Message`s returned at the end of commands (for example using `User#pm` or `Message#edit`) will now no longer be sent ([#66](https://github.com/meew0/discordrb/issues/66))
 - The `:with_text` event attribute is now aliased to `:exact_text` ([#65](https://github.com/meew0/discordrb/issues/65))
 - Server icons (`Server#icon=`) can now be set just like avatars (`Profile#avatar=`)
 - Lots of comments were added to the examples and some bugs fixed
 - The overall performance and memory usage was improved, especially on Ruby 2.3 (using the new frozen string literal comment)
 - The documentation was slightly improved.

**Bugfixes**:
 - A *lot* of latent bugs with caching were fixed. This doesn't really have a noticeable effect, it just means better stability and reliability as a whole.
 - **Command bots no longer respond when there are spaces between the prefix and the command.** Because this behaviour may be desirable, a `spaces_allowed` attribute was added to the CommandBot initializer that can be set to true to re-enable this behaviour.
 - Permission calculation (`User#permission?`) has been thoroughly rewritten and should now account for edge cases like server owners and Manage Permissions.
 - The gateway reconnect logic now uses a correct falloff system - before it would start at 1 second between attempts and immediately jump to 120. Now the transition is more smooth.
 - Commands with aliases now show up correctly in the auto-generated help command ([#72](https://github.com/meew0/discordrb/issues/72))
 - The auto-generated help command can now actually be disabled by setting the corresponding attribute to nil ([#73](https://github.com/meew0/discordrb/issues/73))
 - Including empty containers now does nothing instead of raising an error
 - Command bots now obey `should_parse_self`

## 1.8.1

### Bugfixes
* Fixed an error (caused by an undocumented API change) that would write a traceback to the console every time someone started typing in a channel invisible to the bot.

## 1.8.0
* The built-in logger has been somewhat redone.
  * It now has a fancy mode, settable using `Discordrb::LOGGER.fancy = true/false`, that makes use of ANSI escape codes to prettify the log output.
  * It now supports more things than just `debug`, there's also `warn`, `error`, `good`, `info`, `in`, and `out`.
  * You now have finer control over what gets output, using `Discordrb::LOGGER.mode=` which accepts one of `:debug`, `:verbose`, `:normal`, `:quiet`, `:silent`.
* You can now log in with just a token by setting the email parameter to `:token` and the password to the token you want to log in with.
* DCA playback now supports `DCA1`.
* All data classes (now generalized using the `IDObject` mixin) have a `creation_date` parameter that specifies when the object was created.
* `Channel#mention` was added that mentions a channel analogous to `User#mention`.
* The aliases `tag` and `discord_tag` have been added to the discriminator because that's what Discord calls them now.

### Bugfixes
* A problem some users had where voice playback would leak FFmpeg processes has been fixed.
* The VWS internal thread now has a name in debug messages (`vws-i`)
* Users' voice channels should now always be set if they are in one

## 1.7.5
* `Channel#send_message` and `Bot#send_message` now have an extra `tts` parameter (false by default) to specify whether the message should use TTS.

### Bugfixes
* Attempting to `p` a data class, especially a `User` or `Profile`, should no longer lock up the interpreter due to very deep recursion.
* Manual TTS using `API.send_message` will now work correctly.

## 1.7.4
* Added methods `Channel#text?` and `Channel#voice?` to check a channel's type.
* Frequently allocated strings have been turned into symbols or frozen constants, this should improve performance slightly.

### Bugfixes
* `VoiceBot#destroy` will now properly disconnect you and should no longer cause segfaults.
* Fixed a bug where you couldn't set any settings on a role created using `Server#create_role`.
* Fixed `Profile#avatar=` doing absolutely nothing.

## 1.7.3
* The server banlist can now be accessed more nicely using `Server#bans`.
* Some abstractions for OAuth application creation were added - `bot.create_oauth_application` and `bot.update_oauth_application`. See the docs about how to use them.

## 1.7.2
* The `bot` object can now be read from all events, not just from command ones.
* You can now set the `filter_volume` on VoiceBot, which corresponds to the old way of doing volume handling, in case the new way is too slow for you.

## 1.7.1
* A `clear!` method was added to EventContainer that removes all events from it, so you can overwrite modules by defining them again. (It's unnecessary for CommandContainers because commands can never be duplicate.)

### Bugfixes
* The tokens will now be verified correctly when obtained from the cache. (I messed up last time)
* Events of the same type in different containers will now be merged correctly when including both containers.
* Got rid of the annoying `undefined method 'game' for nil:NilClass` error that sometimes occurred on startup. (It was harmless but now it's gone entirely)

## 1.7.0
* **`bot.find` and `bot.find_user` have had their fuzzy search feature removed because it only caused problems. If you still need it, you can copy the code from the repo's history.** In addition, `find` was renamed to `find_channel` but still exists as a (deprecated) alias.
* The in-line documentation using Yard is now complete and can be [accessed at RubyDoc](http://www.rubydoc.info/github/meew0/discordrb/master/). It's not quite polished yet and some things may be confusing, but it should be mostly usable.
* Events and commands can now be thoroughly modularized using a system I call 'containers'. (TODO: Add a tutorial here later)
* Support for the latest API changes:
  * `Server.leave` does something different than `Server.delete`
  * The WebSocket connection now uses version 3 of the protocol
* Voice bots now support playing DCA files using the [`play_dca`](http://www.rubydoc.info/github/meew0/discordrb/master/Discordrb%2FVoice%2FVoiceBot%3Aplay_dca) method. (TODO: Add a section to the voice tutorial)
* The [volume](http://www.rubydoc.info/github/meew0/discordrb/master/Discordrb%2FVoice%2FVoiceBot%3Avolume) of a voice bot can now be changed during playback and not only for future playbacks.
* A `Channel.prune` method was added to quickly delete lots of messages from a channel. (It appears that this is something lots of bots do.)
* [`Server#members`](http://www.rubydoc.info/github/meew0/discordrb/master/Discordrb%2FServer%3Amembers) is now aliased to `users`.
* An attribute [`Server#member_count`](http://www.rubydoc.info/github/meew0/discordrb/master/Discordrb%2FServer%3Amember_count) was added that is accurate even if chunked members have not been added yet.
* An attribute [`Server#large?`](http://www.rubydoc.info/github/meew0/discordrb/master/Discordrb%2FServer%3Alarge) was added that is true if a server could possibly have an inaccurate list of members.
* Some more specific error classes have been added to replace the RestClient generic ones.
* Quickly sending a message using the `event << 'text'` syntax now works in every type of message event, not just commands.
* You can now set the bitrate of sent audio data using `bot.voice.encoder.bitrate = 64000` (see [`Encoder#bitrate=`](http://www.rubydoc.info/github/meew0/discordrb/master/Discordrb/Voice/Encoder#bitrate%3D-instance_method)). Note that sent audio data will always be unaffected by voice channel bitrate settings, those only tell the client at what bitrate it should send.
* A rate limiting feature was added to commands - you can define buckets using the [`bucket`](http://www.rubydoc.info/github/meew0/discordrb/master/Discordrb%2FCommands%2FRateLimiter%3Abucket) method and use them as a parameter for [`command`](http://www.rubydoc.info/github/meew0/discordrb/master/Discordrb%2FCommands%2FCommandContainer%3Acommand).
  * A [`SimpleRateLimiter`](http://www.rubydoc.info/github/meew0/discordrb/master/Discordrb/Commands/SimpleRateLimiter) class was also added if you want rate limiting independent from commands (e. g. for events)
* Connecting to the WebSocket now uses an exponential falloff system so we don't spam Discord with requests anymore.
* Debug timestamps are now accurate to milliseconds.


### Bugfixes
* The token cacher will now detect whether a cached token has been invalidated due to a password change.
* `break`ing from an event or command will no longer spew `LocalJumpError`s to the console.

## 1.6.6

### Bugfixes
* Fixed a problem that would cause an incompatibility with Ruby 2.1
* Fixed servers sometimes containing duplicate members

## 1.6.5
* The bot will now request the users that would previously be sent all in one READY packet in multiple chunks. This improves startup time slightly and ensures compatibility with the latest Discord change, but it also means that some users won't be in server members lists until a while after creation (usually a couple seconds at most).

## 1.6.4

### Bugfixes
* Fixed a bug that made the joining of servers using an invite impossible.

## 1.6.3

### Bugfixes
* Fixed a bug that prevented the banning of users over the API

## 1.6.2

### Bugfixes
* RbNaCl is now installed directly instead of the wrapper that also contains libsodium. This has the disadvantage that you will have to install libsodium manually but at least it's not broken on Windows anymore.

## 1.6.1
* It's now possible to prevent the `READY` packet from being printed in debug mode, run `bot.suppress_ready_debug` once before the `bot.run` to do it.

### Bugfixes
* Token cache files with invalid JSON syntax will no longer crash the bot at login.

## 1.6.0

* The inline documentation using YARD was greatly improved and is now mostly usable, at least for the data classes and voice classes. It's still not complete enough to be released on GitHub, but you can build it yourself using [YARD](http://yardoc.org/).
* It's now possible to encrypt sent voice data using an optional parameter in `voice_connect`. The encryption uses RbNaCl's [SecretBox](https://github.com/cryptosphere/rbnacl/wiki/Secret-Key-Encryption#algorithm-details) and is enabled by default.
* The [new library comparison](https://discordapi.com/unofficial/comparison.html) is now fully supported, barring voice receive and multi-send: (#39)
  * `bot.invite` will create an `Invite` object from a code containing information about it.
  * `server.move(user, channel)` will move a user to a different voice channel.
  * The events `bot.message_edit` and `bot.message_delete` are now available for message editing and deletion. Note that Discord doesn't provide the content of edited/deleted messages, so you'll have to implement message caching yourself if you really need it.
  * The events `bot.user_ban` and `bot.user_unban` are now available for users getting banned/unbanned from servers.
* A bot's name can now be sent using `bot.name=`. This data will be sent to Discord with the user-agent and it might be used for cool statistics in the future.
* Discord server ownership transfer is now implemented using the writer `server.owner=`. (#41)
* `CommandBot`s can now have command aliases by simply using an array of symbols as the command name.
* A utility method `server.default_channel` was implemented that returns the default text channel of a server, usually called #general. (An alias `general_channel` is available too.)
* Tokens will no longer appear in debug output, so you're safe sending output logs to other people.
* A reader `server.owner` that returns the server's owner as a `User` was added. Previously, users had to manually get the `User` object using `bot.user`.
* Most methods that accept IDs or data objects now also accept `Integer`s or `String`s containing the IDs now. This is implemented by adding a method `resolve_id` to all objects that could potentially contain an ID. (Note that this change is not complete yet and I might have missed some methods.) (#40)
* The writer `server.afk_channel_id=` is now deprecated as its functionality is now covered by `server.afk_channel=`.
* A new reader `user.avatar_url` was added that returns the full image URL to a user's avatar.
* To avoid confusion with `avatar_url`, the reader `user.avatar` was renamed to `avatar_id`. (`user.avatar` still exists but is now deprecated.)
* Symbols are now used instead of strings as hash keys in all methods that send JSON data to somewhere. This might improve performance slightly.

### Bugfixes
* Fixed the reader `server.afk_channel_id` not containing a value sometimes.
* An issue was fixed where attempting to create a `Server` object from a stub server that didn't contain any role data would cause an exception.
* The `Invite` `server` property will now be initialized directly from the invite data instead of the channel the invite is to, to prevent it being `nil` when the invite channel was stubbed.
* The `inviter` of an `Invite` will now be `nil` instead of causing an exception when it doesn't exist in the invite data.

## 1.5.4
* The `opus-ruby` and `levenshtein` dependencies are now optional - if you don't need them, it won't crash immediately (only when you try to use voice / `find` with a threshold > 0, respectively)

### Bugfixes
* Voice volume can now be properly set when using avconv (#37, thanks @purintai)
* `websocket-client-simple`, which is required for voice, is now specified in the dependencies.

## 1.5.3
* Voice bot length adjustments are now configurable using `bot.voice.adjust_interval` and `bot.voice.adjust_offset` (make sure the latter is less than the first, or no adjustment will be performed at all)
* Length adjustments can now be made more smooth using `bot.voice.adjust_average` (true allows for more smooth adjustments, *may* improve stutteriness but might make it worse as well)

## 1.5.2
* `bot.voice_connect` can now use a channel ID directly.
* A reader `bot.volume` now exists for the corresponding writer.
* The attribute `bot.encoder.use_avconv` was added that makes the bot use avconv instead of ffmpeg (for those on Ubuntu 14.x)
* The PBKDF2 iteration count for token caching was increased to 300,000 for extra security.

### Bugfixes
* Fix a bug where `play_file` wouldn't properly accept string file paths (#36, thanks @purintai)
* Fix a concurrency issue where `VoiceBot` would try to read from nil


## 1.5.1
* The connection to voice was made more reliable. I haven't experienced any issues with it myself but I got reports where `recv` worked better than `recvmsg`.

## 1.5.0
* Voice support: discordrb can now connect to voice using `bot.voice_connect` and do the following things:
  * Play files and URLs using `VoiceBot.play_file`
  * Play arbitrary streams using `VoiceBot.play_io`
  * Set the volume of future playbacks using `VoiceBot.volume=`
  * Pause and resume playback (`VoiceBot.pause` and `VoiceBot.continue`)
* Authentication tokens are now cached and no login request will be made if a cached token is found. This is mostly to reduce strain on Discord's servers.

### Bugfixes
* Some latent ID casting errors were fixed - those would probably never have been noticed anyway, but they're fixed now.
* `Bot.parse_mention` now works, it didn't work at all previously

## 1.4.8
* The `User` class now has the methods `add_role` and `remove_role` which add a role to a user and remove it, respectively.
* All data classes now have a useful `==` implementation.
* **The `Game` class and all references to it were removed**. Games are now only identified by their name.

### Bugfixes
* When a role is deleted, the ID is now obtained correctly. (#30)

## 1.4.7
* Presence event handling is now divided into two separate events; `PresenceEvent` to handle online/offline/idle statuses and `PlayingEvent` to handle users playing games.
* The `user` property of `MessageEvent` is now automatically resolved to the cached user, so you can modify roles instantly without having to resolve it yourself.
* `Message` now has a useful `to_s` method that just returns the content.

### Bugfixes
* The `TypingEvent` `user` property is now initialized correctly (#29, thanks @purintai)

## 1.4.6
*Bugfix-only release.*

### Bugfixes
* The `user` and `server` properties of `PresenceEvent` are now initialized correctly.

## 1.4.5
* The `Bot.game` property can now be set to an arbitrary string.
* Discord mentions are handled in the old way again, after Discord reverted an API change.

## 1.4.4
* Add `Server.leave_server` as an alias for `delete_server`
* Use the new Discord mention format (mentions array). **Reverted in 1.4.5**
* Discord rate limited API calls are now handled correctly - discordrb will try again after the specified time.
* Debug logging is now handled by a separate `Logger` class

### Bugfixes
* Message timestamps are now parsed correctly.
* The quickadders for awaits (`User.await`, `Channel.await` etc.) now add the correct awaits.

## 1.4.3
* Added a method `Bot.find_user` analogous to `Bot.find`.

### Bugfixes
* Remove a leftover debug line (#23, thanks @VxJasonxV)

## 1.4.2
* discordrb will now send a user agent in the format requested by the Discord devs.

## 1.4.1
*Bugfix-only release.*

### Bugfixes
* Empty messages will now never be sent
* The command-not-found message in `CommandBot` can now be disabled properly

## 1.4.0
* All methods and classes where the words "colour" or "color" are used now have had aliases added with the respective other spelling. (Internally, everything uses "colour" now).
* discordrb now supports everything on the Discord API comparison, except for voice (see also #22)
  * Roles can now be created, edited and deleted and their permissions modified.
  * There is now a method to get a channel's message history.
  * The bot's user profile can now be edited.
  * Servers can now be created, edited and deleted.
  * The user can now display a "typing" message in a channel.
  * Invites can now be created and deleted, and an `Invite` class was made to represent them.
* Command and event handling is now threaded, with each command/event handler execution in a separate thread.
* Debug messages now specify the current thread's name.
* discordrb now handles created/updated/deleted servers properly with events added to handle them.
* The list of games handled by Discord will now be updated automatically.

### Bugfixes
* Fixed a bug where command handling would crash if the command didn't exist.

## 1.3.12
* Add an attribute `Bot.should_parse_self` (false by default) that prevents the bot from raising an event if it receives a message from itself.
* `User.bot?` and `Message.from_bot?` were implemented to check whether the user is the bot or the message was sent by it.
* Add an event for private messages specifically (`Bot.pm` and `PrivateMessageEvent`)

### Bugfixes
* Fix the `MessageEvent` attribute that checks whether the message is from the bot not working at all.

## 1.3.11
* Add a user selector (`:bot`) that is usable in the `from:` `MessageEvent` attribute to check whether the message was sent by a bot.

### Bugfixes
* `Channel.private?` now checks for the server being nil instead of the `is_private` attribute provided by Discord as the latter is unreliable. (wtf)

## 1.3.10
* Add a method `Channel.private?` to check for a PM channel
* Add a `MessageEvent` attribute (`:private`) to check whether a message was sent in a PM channel
* Add various aliases to `MessageEvent` attributes
* Allow regexes to check for strings in `MessageEvent` attributes

### Bugfixes
* The `matches_all` method would break in certain edge cases. This didn't really affect discordrb and I don't think anyone else uses that method (it's pretty useless otherwise). This has been fixed

## 1.3.9
* Add awaits, a powerful way to add temporary event handlers.
* Add a `Bot.find` method to fuzzy-search for channels.
* Add methods to kick, ban and unban users.

### Bugfixes
* Permission overrides now work correctly for private channels (i. e. they don't exist at all)
* Users joining and leaving servers are now handled correctly.

## 1.3.8
* Added `Bot.users` and `Bot.servers` readers to get the list of users and servers.

### Bugfixes
* POST requests to API calls that don't need a payload will now send a `nil` payload instead. This fixes the bot being unable to join any servers and various other latent problems. (#21, thanks @davidkus)

## 1.3.7
*Bugfix-only release.*

### Bugfixes
* Fix the command bot being included wrong, which caused crashes upon startup.

## 1.3.6
* The bot can now be stopped from the script using the new method `Bot.stop`.

### Bugfixes
* Fix some wrong file requires which caused crashes sometimes.

## 1.3.5
* The bot can now be run asynchronously using `Bot.run(:async)` to do further initialization after the bot was started.
