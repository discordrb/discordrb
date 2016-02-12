# Changelog

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
