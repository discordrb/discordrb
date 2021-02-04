# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
## [3.4.1] - 2020-2-4
[3.4.1]: https://github.com/shardlab/discordrb/releases/tag/v3.4.1

[View diff for this release.](https://github.com/shardlab/discordrb/compare/v3.4.0..v3.4.1)

### Summary

With 3.4.0, mistakes were made during the version bump leading to a bit of a dependency issue between `discordrb` and `discordrb-webhooks` (sorry!).
This micro bump fixes this, fixes a few other code issues, and adds a few minor features.

### Added
- Added support for `competing` activity types ([#21](https://github.com/shardlab/discordrb/pull/21), thanks @kaine119)
- Support for a callable command_does_not_exist_message ([#25](https://github.com/shardlab/discordrb/pull/25), thanks @kmcphillips)

### Fixed
- `Bot#send_temporary_message` now properly passes `message_reference` ([#17](https://github.com/shardlab/discordrb/pull/17) thanks @swarley)
- Rate limit precision is only supplied when the route requires headers ([#11](https://github.com/shardlab/discordrb/pull/11) thanks @dali546)
- Remove pointless conditional in `Invite` initializer ([#26](https://github.com/shardlab/discordrb/pull/26) thanks @swarley)
- All API methods link to their official documentation counterparts ([#12](https://github.com/shardlab/discordrb/pull/12) thanks @kaine119)
- Links to messages now work when a `guild_id` is not present in a non DM message. ([#27](https://github.com/shardlab/discordrb/pull/27) thanks @swarley)

## [3.4.0] - 2020-12-06
[3.4.0]: https://github.com/shardlab/discordrb/releases/tag/v3.3.0

[View diff for this release.](https://github.com/shardlab/discordrb/compare/v3.4.0...v3.3.0)

### Summary

This release has been a _very_ long time coming. It brings countless fixes, performance increases, features, and changes. So many in fact, that it's only feasible to put the major hilights in summary.

The largest additions are that of intents support and a massive performance increase in our websocket read loop.

Intents allow you to pick and choose what types of events are fed to your bot over the gateway. An example usage would be:

```ruby
Discordrb::Bot.new(token: 'B0T.T0K3N', intents: %i[servers server_messages])
```


In this example, we would only recieve the following events
- GUILD_CREATE
- GUILD_UPDATE
- GUILD_DELETE
- GUILD_ROLE_CREATE
- GUILD_ROLE_UPDATE
- GUILD_ROLE_DELETE
- CHANNEL_CREATE
- CHANNEL_UPDATE
- CHANNEL_DELETE
- CHANNEL_PINS_UPDATE
- MESSAGE_CREATE
- MESSAGE_UPDATE
- MESSAGE_DELETE
- MESSAGE_DELETE_BULK

This feature is still experimental, as it is still unclear how some interactions within the library behave when denied previously expected events. This support will improve over time. If you want more information on intents you can read [the official documentation](https://discord.com/developers/docs/topics/gateway#gateway-intents) as well as the documentation for `Discordrb::INTENTS` and `Discordrb::Bot#initialize`.

### Added

- `Bot#parse_mentions`, which extracts *all* mentions found in a string ([#526](https://github.com/discordrb/discordrb/pull/526), thanks @SanksTheYokai)
- Issue and pull request templates ([#585](https://github.com/discordrb/discordrb/pull/585))
- `Server#bot` method for obtaining your bot's own `Member` on a particular server ([#597](https://github.com/discordrb/discordrb/pull/597))
- `Attachment#spoiler?`, to check if an attachment is a spoiler or not ([#603](https://github.com/discordrb/discordrb/pull/603), thanks @swarley)
- Methods on `Server` to manage the server's emoji ([#595](https://github.com/discordrb/discordrb/pull/595), thanks @swarley)
- `Paginator` utility class for wrapping paginated endpoints ([#579](https://github.com/discordrb/discordrb/pull/579))
- `EventContainer#message_update`, which is fired whenever a message is updated, either by Discord or the user ([#612](https://github.com/discordrb/discordrb/pull/612), thanks @swarley)
- `Message#server` ([#614](https://github.com/discordrb/discordrb/pull/614), thanks @swarley)
- `Channel#news?`, `Channel#store?` ([#618](https://github.com/discordrb/discordrb/pull/618), thanks @swarley)
- `Server#bot_members`, `Server#non_bot_members` ([#626](https://github.com/discordrb/discordrb/pull/626), thanks @flutterflies)
- `API.get_gateway_bot` ([#632](https://github.com/discordrb/discordrb/pull/632))
- `Channel#create_webhook` ([#637](https://github.com/discordrb/discordrb/pull/637), thanks @Chew)
- `User#dnd?` and documentation for other user status methods ([#679](https://github.com/discordrb/discordrb/pull/679), thanks @kaine119)
- `Message#link`, `Channel#link`, `Server#link` ([commit](https://github.com/shardlab/discordrb/commit/44f93948a812e06b439968c6b072c0d9b749a842), thanks @z64)
- `ReactionEvent#message_id` and `message` option for `ReactionEventHandler` ([#728](https://github.com/discordrb/discordrb/pull/728), thanks @swarley)
- `intents` option for `Bot#initialize`, `INTENTS`, and `ALL_INTENTS` for experimental intents support ([#698](https://github.com/discordrb/discordrb/pull/698), thanks @swarley)
- `reason` positional arguments for various API methods, support for new audit log events ([#682](https://github.com/discordrb/discordrb/pull/682), thanks @swarley)
- Support for `attachment://` procotol linking in `API::Channel.create_message` and methods that utilize it (`Bot#send_message`, `Channel#send_message`, `Channel#send_temporary_message`, `Channel#send_embed`, `Respondable#send_message`, `Respondable#send_embed`) ([#735](https://github.com/discordrb/discordrb/pull/735), thanks @swarley)
- `AllowedMentions`, and `allowed_mentions` positional arguments to `API::Channel.create_message`, `Bot#send_message`, `Bot#send_temporary_message`, `Channel#send_message`, `Channel#send_temporary_message`, `Channel#send_embed`, `Respondable#send_message`, `Respondable#send_embed`, and `Respondable#send_temporary_message` ([#708](https://github.com/discordrb/discordrb/pull/708), thanks @swarley)
- `with_counts` optional positional argument to `API::Server.resolve` ([#709](https://github.com/discordrb/discordrb/pull/709), thanks @swarley)
- Expose full options to `Bot#send_temporary_message` and `Respondable#send_temporary_message` ([commit](https://github.com/shardlab/discordrb/commit/d20203211603cd4c06212d99e733bf5f5b3c8f0b), thanks @Birdie0)
- `User#client_status`, `PresenceEvent#client_status`, and `client_status` option for `EventContainer#presence` ([#736](https://github.com/discordrb/discordrb/pull/736), thanks @swarley)
- `VoiceServerUpdateEvent`, and `EventContainer#voice_server_update` ([#743](https://github.com/discordrb/discordrb/pull/743), thanks @swarley)
- Invite events, `InviteCreateEvent`, `InviteDeleteEvent`, `EventContainer#invite_create`, `EventContainer#invite_delete` and `Server#splash_hash` ([#744](https://github.com/discordrb/discordrb/pull/744), thanks @swarley)
- `Message#reply!`, `Message#reply?`, `Message#referenced_message` for inline reply support ([#3](https://github.com/shardlab/discordrb/pull/3), thanks @swarley)

### Changed

- Drop support for Ruby 2.3 (EOL) ([#583](https://github.com/discordrb/discordrb/pull/583), thanks @PanisSupraOmnia)
- **(breaking change)** Upgraded minimum Ruby version to 2.3.7, and upgraded Rubocop to 0.60.0. This additionally changes the name of some public constants. ([#487](https://github.com/discordrb/discordrb/pull/487), thanks @PanisSupraOmnia)
- Dependencies for `rbnacl`, `rake`, and `rspec` have been updated ([#538](https://github.com/discordrb/discordrb/pull/538), thanks @PanisSupraOmnia)
- The monolithic `data.rb` file has been split into multiple files for easier development ([#482](https://github.com/discordrb/discordrb/pull/482))
- Loosened `bundler` development dependency to allow use of `bundler` 1.x and 2.x ([#591](https://github.com/discordrb/discordrb/pull/591), thanks @PanisSupraOmnia)
- `API::Server.create_channel` and `Server#create_channel` now accepts `position` ([#592](https://github.com/discordrb/discordrb/pull/592), thanks @swarley)
- `Bot.new` will now raise a more helpful exception when the passed token string is empty or nil ([#599](https://github.com/discordrb/discordrb/pull/599))
- `compress_mode` in `Bot.new` now defaults to `:large` instead of `:stream` ([#601](https://github.com/discordrb/discordrb/pull/601))
- `send_file` methods now accept `filename` to rename a file when uploading to Discord ([#605](https://github.com/discordrb/discordrb/pull/605), thanks @swarley)
- Emoji related `API` methods now accept arguments to change an emoji's role whitelist ([#595](https://github.com/discordrb/discordrb/pull/595), thanks @swarley)
- `send_file` API now accepts a `spoiler` kwarg to send the file as a spoiler ([#606](https://github.com/discordrb/discordrb/pull/606), thanks @swarley)
- Clarified use of `API.bot_name=` ([#622](https://github.com/discordrb/discordrb/pull/622), thanks @Daniel-Worrall)
- `Message#reacted_with` can now return all users who reacted with an emoji, instead of just the first 25 ([#615](https://github.com/discordrb/discordrb/pull/615), thanks @swarley)
- `Server#create_channel` can create store and news channels, if you have access to do so ([#618](https://github.com/discordrb/discordrb/pull/618), thanks @swarley)
- Typestrings for API that accepts discord IDs is now consistently represented as `String, Integer` ([#616](https://github.com/discordrb/discordrb/pull/616), thanks @swarley)
- When a command is executed with an invalid number of arguments, the error response is sent as a single message ([#627](https://github.com/discordrb/discordrb/pull/627))
- The `#split_send` utility method returns `nil`, to avoid the case where the return value is captured in the implicit return message ([#629](https://github.com/discordrb/discordrb/pull/629), thanks @captainSV)
- Give up reconnecting after receiving a fatal close code ([#633](https://github.com/discordrb/discordrb/pull/633))
- Misc upgrades to RuboCop v0.68 ([#624](https://github.com/discordrb/discordrb/pull/624), thanks @PanisSupraOmnia)
- `await!` methods now accept a block to test for matching event conditions ([#635](https://github.com/discordrb/discordrb/pull/635), thanks @z64)
- Dependency updates for RuboCop v0.74, redcarpet, and simplecov ([#636](https://github.com/discordrb/discordrb/pull/636), thanks @PanisSupraOmnia)
- Update voice logic to connect to the IP address from READY ([#644](https://github.com/discordrb/discordrb/pull/644), thanks @swarley)
- Refactored use of enumerable code in `Discordrb.split_message` ([#646](https://github.com/discordrb/discordrb/pull/646), thanks @piharpi)
- **(deprecated)** `no_sync` argument in `Bot#stop` is now considered deprecated as part of a refactor that removes Ruby 2.3 compatibility ([#652](https://github.com/discordrb/discordrb/pull/652), thanks @PanisSupraOmnia)
- Return `rest-client` dependency to `>= 2.0.0` since `2.1.0` is now released ([#654](https://github.com/discordrb/discordrb/pull/654), thanks @ali-l)
- Added Bit for "Streaming" permission ([#660](https://github.com/discordrb/discordrb/pull/660), thanks @NCPlayz)
- Methods for Nitro boosting related information ([#638](https://github.com/discordrb/discordrb/pull/638), thanks @Chew)
- `ServerDeleteEvent#server` now returns an `Integer` ([commit](https://github.com/discordrb/discordrb/commit/bb457fe981d2b997b704ad85008ec3b185b046e8), thanks @z64)
- User activites are now represented by `ActivitySet`, from `User#activities` ([#677](https://github.com/discordrb/discordrb/pull/677), thanks @swarley)
- **(deprecated)** `User#game`, `User#stream_type`, and `User#stream_url` are considered deprecated in favor of `ActivitySet#games` and `ActivitySet#streaming` as activities are no longer considered to be singular. ([#677](https://github.com/discordrb/discordrb/pull/677), thanks @swarley)
- Non CDN links now use the updated domain name `https://discord.com` ([#720](https://github.com/discordrb/discordrb/pull/720), thanks @swarley)
- Additional fields are included in `Role#inspect` ([#731](https://github.com/discordrb/discordrb/pull/731), thanks @IotaSpencer)
- `Invite#server` and `Invite#channel` can both return partial or full objects depending on the data source ([#744](https://github.com/discordrb/discordrb/pull/744), thanks @swarley)
- Members now have the `@everyone` role ([#739](https://github.com/discordrb/discordrb/pull/739), thanks @kdance21)
- Add `message_reference` as an optional positional argument to the following methods. `API::Channel.create_message`, `Bot#send_message`, `Channel#send_message`, `Channel#send_temporary_message`, `Channel#send_embed`, `Events::MessageEvent#send_message`, and `Events::MessageEvent#send_embed` ([#3](https://github.com/shardlab/discordrb/pull/3), thanks @swarley)
- **(deprecated)** `Message#reply` has been deprecated in favor of `Message#respond`, and the functionality will be replaced with that of `reply!` in 4.0 ([#3](https://github.com/shardlab/discordrb/pull/3), thanks @swarley)

### Fixed

- Permission calculation when the internal sorting of roles is unreliable ([#609](https://github.com/discordrb/discordrb/pull/609))
- `DisconnectEvent` is now raised when a gateway close frame is handled ([#611](https://github.com/discordrb/discordrb/pull/611), thanks @swarley)
- A cached `Channel` is no longer assumed to be NSFW if its name starts with `nsfw` ([#617](https://github.com/discordrb/discordrb/pull/617), thanks @swarley)
- **(breaking change)** `Message#reactions` is changed to return an Array instead of a hash, fixing reactions with the same `name` value from being discarded (#[593](https://github.com/discordrb/discordrb/pull/596))
- `Channel#nsfw=` correctly forwards updated value to the API ([#628](https://github.com/discordrb/discordrb/pull/628))
- `Emoji#==` works correctly for unicode emoji ([#590](https://github.com/discordrb/discordrb/pull/590), thanks @soukouki)
- Attribute matching for voice state update events ([#625](https://github.com/discordrb/discordrb/pull/625), thanks @swarley) 
- `Emoji#to_reaction` works correctly for unicode emoji ([#642](https://github.com/discordrb/discordrb/pull/642), thanks @z64)
- `Server#add_member_using_token` returns `nil` when user is already a member ([#643](https://github.com/discordrb/discordrb/pull/643), thanks @swarley)
- `CommandBot`'s `Integer` parser interprets all integers as base 10 ([#656](https://github.com/discordrb/discordrb/pull/656), thanks @joshleblanc)
- Broken reference link in `CommandBot#initialize` documentation ([#647](https://github.com/discordrb/discordrb/pull/647), thanks @Daniel-Worrall)
- Return the correct value for `Message#reactions?` ([#729](https://github.com/discordrb/discordrb/pull/729), thanks @swarley)
- Gateway closes with a 4000 code on `RECONNECT`, preserving the session ([#727](https://github.com/discordrb/discordrb/pull/727), thanks @swarley)
- `Emoji#mention` works correctly for unicode emojis ([#715](https://github.com/discordrb/discordrb/pull/715), thanks @swarley)
- Voice now uses gateway v4 ([#648](https://github.com/discordrb/discordrb/pull/648), thanks @swarley)
- VoiceBot now sends a `KILL` signal instead of `TERM` on Windows hosts when ending the ffmpeg process. ([#732](https://github.com/discordrb/discordrb/pull/732), thanks @swarley)
- `Message#emoji` returns more reliably when used with other mention types ([#724](https://github.com/discordrb/discordrb/pull/724), thanks @omnilord)
- Permission calculation now properly considers overwrites ([#712](https://github.com/discordrb/discordrb/pull/712), thanks @swarley)

### Removed

- Removed dependency on `rbnacl` in favor of our own FFI bindings ([#641](https://github.com/discordrb/discordrb/pull/641), thanks @z64)

## [3.3.0] - 2018-10-27
[3.3.0]: https://github.com/discordrb/discordrb/releases/tag/v3.3.0

[View diff for this release.](https://github.com/discordrb/discordrb/compare/v3.2.1...v3.3.0)


### Summary

3.3.0 brings discordrb up to speed with new features added to Discord's API over the last year. Included is a large number of fixes, optimizations, and library features.

Since there is a lot here, here are highlights of the more notable changes in this release:

- We now use SSL certificate validation in our gateway connections, and enforce use of TLSv1.2. If this is an issue
  for your platform or environment (you get errors related to SSL), please report this with relevant details. You
  can revert to the old codepath at any time by setting `DISCORDRB_SSL_VERIFY_NONE`. This environment variable will
  be removed in a later release when this proves to be a stable default.

- `CommandBot` now supports a new method of "aliasing" commands with the `aliases:` keyword. It accepts an array
  of symbols of alternate command names. Currently this is supported by passing an array of symbols for the command
  name itself, but this essentially makes "copies" of the command, meaning each alias will show up in your help command.
  Using `aliases` instead, the library will recognize that these other names *are aliases* instead of copying the command.
  Aliases will be listed when users use `!help` with the command name, or any of its aliases. For now you may chose to use
  either style, but you cannot use both. Specifying an array for the command name is now considered deprecated.

- There are now two methods of creating "awaits" in discordrb. The new style is a blocking (synchronous) method that
  uses threads and regular event handlers in the background. The new methods are all named with a bang (`!`),
  i.e. `user.await!`, `message.await!`, and simply return the raised event. This system should be less confusing than
  the current asynchronous one. These blocking awaits no longer have an identifying key and only accept the event
  attributes as an argument. There is also a special reserved attribute called `timeout` that will stop waiting for
  an event and return `nil` if the given number of seconds has passed. Eventually this new system of awaits will
  replace the old one in a later breaking change. A short example:

```ruby
bot.message(content: '!test') do |event|
  event.respond 'What is your name?'
  response = event.message.await!(timeout: 3)
  if response
    event.respond "Hello, #{response.message.content}!"
  else
    event.respond 'You took too long!'
  end
end
```

The entire changelog follows, with items that contain breaking changes noted. If you use parts of the library
mentioned in a breaking change, you can read the PR and diff for the full details. If you need help with
understanding, updating your bot, or have any other questions, please feel free to [join us on Discord](https://discord.gg/cyK3Hjm)
or open an issue if necessary.

Thank you to all of our contributors!

### Added

- API methods to add and remove single member roles ([#310](https://github.com/discordrb/discordrb/pull/310))
- **(breaking change)** API methods and abstractions for listing available voice regions ([#311](https://github.com/discordrb/discordrb/pull/311))
- `Server` methods to prune members and to get the number of members available for pruning ([#315](https://github.com/discordrb/discordrb/pull/315))
- Methods for filtering the kinds of overwrites present on a channel ([#321](https://github.com/discordrb/discordrb/pull/321))
- `Channel#default_channel?`, for checking if a channel is the default channel of a server ([#320](https://github.com/discordrb/discordrb/pull/320), thanks @Reaver01)
- Method for returning a `Server`'s `@everyone` role
- Reactions can now be serialized with `#to_s` to be used in `Message#react` more easily ([#342](https://github.com/discordrb/discordrb/pull/342))
- Additional objects and attributes for parsing embeds on messages ([#344](https://github.com/discordrb/discordrb/pull/344), thanks @mattantonelli)
- Methods for finding a members highest role, the role that is hoisting the member, or giving the member color ([#335](https://github.com/discordrb/discordrb/pull/335), thanks @Snazzah)
- API support for managing webhooks ([#356](https://github.com/discordrb/discordrb/pull/356), thanks @Daniel-Worrall)
- Support for reading and managing a channel's `nsfw` property ([#380](https://github.com/discordrb/discordrb/pull/380))
- The `:administrator` permissions value is aliased as `:administrate` ([#322](https://github.com/discordrb/discordrb/pull/322))
- Class methods on `Permissions` for easily building permissions bits values ([#322](https://github.com/discordrb/discordrb/pull/322))
- `Gateway#send_packet` and `Gateway#send_raw` methods to send custom data payloads to the gateway
- Methods for reading `icon_url` and `proxy_icon_url` in `EmbedAuthor`
- Methods for obtaining a server and channels invites ([#394](https://github.com/discordrb/discordrb/pull/394))
- Example of using awaits ([#370](https://github.com/discordrb/discordrb/pull/370))
- Methods on `Member` for kicking and banning ([#404](https://github.com/discordrb/discordrb/pull/404))
- API method and abstraction for adding members to guilds with OAuth2 tokens ([#413](https://github.com/discordrb/discordrb/pull/413))
- Example of using a prefix proc ([#411](https://github.com/discordrb/discordrb/pull/411))
- **(breaking change)** Methods for managing a server's system channel ([#437](https://github.com/discordrb/discordrb/pull/437), thanks @ldelelis)
- **(breaking change)** Additional error code constants ([#419](https://github.com/discordrb/discordrb/pull/419), thanks @LikeLakers2)
- Commands can be created with a `:rescue` argument, to provide a message or callback when an unhandled exception is raised when executing the command ([#360](https://github.com/discordrb/discordrb/pull/360))
- **(breaking change)** Additional `Server` properties for verification levels, default message notification levels, and explicit content filter settings ([#414](https://github.com/discordrb/discordrb/pull/414), thanks @PixeLInc)
- **(breaking change)** `nonce` is accepted in `API::Channel.create_message` ([#414](https://github.com/discordrb/discordrb/pull/414), thanks @PixeLInc)
- Setters for new status options (`Bot#listening=`, `Bot#watching=`) ([#432](https://github.com/discordrb/discordrb/pull/432), thanks @PixeLInc)
- Documentation examples for sending a file ([#409](https://github.com/discordrb/discordrb/pull/409))
- Respondable implements `#send_embed` ([#420](https://github.com/discordrb/discordrb/pull/420))
- `Invite` now supplies `max_age` and `created_at`
- `Invite` now supplies `member_count` and `online_member_count` ([#454](https://github.com/discordrb/discordrb/pull/454), thanks @Snazzah)
- `Server` methods for managing a server's embed (widget) settings ([#435](https://github.com/discordrb/discordrb/pull/435))
- **(breaking change)** Support for category channels in `Server` and `Channel` ([#415](https://github.com/discordrb/discordrb/pull/415), [#477](https://github.com/discordrb/discordrb/pull/477), thanks @omnilord)
- `CommandBot` and commands channel whitelist can now be modified after creation ([#446](https://github.com/discordrb/discordrb/pull/446), thanks @omnilord)
- A `Role`'s `position` can now be sorted relative to other roles ([#445](https://github.com/discordrb/discordrb/pull/445), thanks @mattantonelli)
- The `return` keyword inside of commands can be used to return content to Discord ([#462](https://github.com/discordrb/discordrb/pull/462), thanks @TrenchFroast)
- `Emoji` now supplies `animated` ([#464](https://github.com/discordrb/discordrb/pull/464), thanks @PixeLInc)
- Additional instructions for installation of Ruby's devkit for Ruby 2.3+ ([#468](https://github.com/discordrb/discordrb/pull/468), thanks @oct2pus)
- `Server` API for retrieving a server's audit logs ([#353](https://github.com/discordrb/discordrb/pull/353), thanks @Snazzah)
- `EventContainer` methods for server role create, delete, and update events ([#494](https://github.com/discordrb/discordrb/pull/494), thanks @Daniel-Worrall)
- `PlayingEvent` now returns `details` ([#486](https://github.com/discordrb/discordrb/pull/486), thanks @xTVaser)
- `Role` now supplies `server` ([#505](https://github.com/discordrb/discordrb/pull/505), thanks @micke)
- Documentation for the `discordrb-webhooks` gem in `README.md` ([#460](https://github.com/discordrb/discordrb/pull/460))
- A new, synchronous awaits system available via `#await!` ([#499](https://github.com/discordrb/discordrb/pull/499))
- `Channel#sort_after`, for moving a channel around a server within categories easily ([#497](https://github.com/discordrb/discordrb/pull/497))
- The gemspec now includes a link to the changelog ([#515](https://github.com/discordrb/discordrb/pull/515), thanks @PanisSupraOmnia)
- Commands can now be restricted by either `allowed_roles` or `required_roles` ([#469](https://github.com/discordrb/discordrb/pull/469), thanks @elfenars)
- `Bot#parse_mention` parses `Channel` mentions ([#525](https://github.com/discordrb/discordrb/pull/525), thanks @estherbolik)
- Support for Discord's `zlib-stream` gateway compression, as well as options to configure the compression mode in `Bot#initialize` ([#527](https://github.com/discordrb/discordrb/pull/527), thanks @oct2pus for additional testing)
- "Priority Speaker" permission bit ([#530](https://github.com/discordrb/discordrb/pull/530), thanks @Chewsterchew)
- Implemented `aliases` attribute in commands, for an improved alternative to "command copying" by passing an array to the command name ([#524](https://github.com/discordrb/discordrb/pull/524))
- **(breaking change)** Methods for managing a `Channel`'s slowmode settings ([#573](https://github.com/discordrb/discordrb/pull/573), thanks @badBlackShark)

### Changed

- `Channel#make_invite` now accepts an argument to always return a unique invite code ([#312](https://github.com/discordrb/discordrb/pull/312))
- More of the API accepts objects that respond to `#resolve_id` ([#313](https://github.com/discordrb/discordrb/pull/313), [#328](https://github.com/discordrb/discordrb/pull/328), thanks @Likelakers2)
- **(breaking change)** `Channel#history` and `API::Channel.messages` now accepts `around_id` ([#314](https://github.com/discordrb/discordrb/pull/314))
- **(breaking change)** `API::Server.prune_count` accepts `days` ([#315](https://github.com/discordrb/discordrb/pull/315))
- **(breaking change)** Methods for creating channels accept additional arguments ([#321](https://github.com/discordrb/discordrb/pull/321))
- `Channel` overwrite-related API now returns an `Overwrite` object ([#321](https://github.com/discordrb/discordrb/pull/321))
- **(breaking change)** Creating roles now accepts more parameters ([#323](https://github.com/discordrb/discordrb/pull/323), thanks @Reaver01)
- Rate limits are now logged to a `:ratelimit` logging level and can be configured
- `client_id` in `Bot#initilalize` is now optional, and will be cached automatically by the API when needed ([#337](https://github.com/discordrb/discordrb/pull/337))
- `Voice::Encoder#encode_file` now accepts options for ffmpeg ([#341](https://github.com/discordrb/discordrb/pull/341), thanks @oyisre)
- Objects that implement `IDObject` can now be compared using more operators ([#346](https://github.com/discordrb/discordrb/pull/346), thanks @mattantonelli)
- Filled in permissions bit for viewing a server's audit log ([#349](https://github.com/discordrb/discordrb/pull/349), thanks @Daniel-Worrall)
- https://cdn.discordapp.com is now used as the base URL for CDN resources like avatars and server icons ([#358](https://github.com/discordrb/discordrb/pull/358))
- Reaction events raised from the bot's actions will respect `parse_self` ([#350](https://github.com/discordrb/discordrb/pull/350), thanks @Daniel-Worrall)
- `Webhooks::Embed#initialize` parses its `color`/`colour` argument ([#364](https://github.com/discordrb/discordrb/pull/364), thanks @Daniel-Worrall)
- Webhook related events can now be matched on webhook ID ([#363](https://github.com/discordrb/discordrb/pull/363), thanks @Daniel-Worrall)
- Discord's default user avatar URLs will now be returned when applicable ([#375](https://github.com/discordrb/discordrb/pull/375))
- `Cache#find_user` can now find individual users if name and discriminator is given ([#384](https://github.com/discordrb/discordrb/pull/384))
- `ReactionEvent` provides both `server` and `member`, if possible ([#351](https://github.com/discordrb/discordrb/pull/351), thanks @Daniel-Worrall)
- Installation instructions now include guides for installing with Bundler ([#386](https://github.com/discordrb/discordrb/pull/386), [#405](https://github.com/discordrb/discordrb/pull/405), thanks @VxJasonxV and @PixeLInc)
- **(breaking change)** `default_channel` implementation is updated to reflect Discord changes ([#382](https://github.com/discordrb/discordrb/pull/382), [#534](https://github.com/discordrb/discordrb/pull/534))
- Documentation around the conditions where our API returns `nil` is clarified ([#395](https://github.com/discordrb/discordrb/pull/395), thanks @LikeLakers2)
- Whenever possible, we update cached data about a `Server` returned to us from making changes to it
- **(breaking change)** `Cache#server` now returns `nil` if a server is not found instead of raising an exception ([#424](https://github.com/discordrb/discordrb/pull/424), thanks @soukouki)
- `Bucket#rate_limited?` now accepts an `increment` value for weighted rate limits ([#427](https://github.com/discordrb/discordrb/pull/427), thanks @Lavode)
- **(breaking change)** `Server#bans` now returns `Array<ServerBan>`, which contains `reason` data in addition to the user banned ([#404](https://github.com/discordrb/discordrb/pull/404))
- `Channel#prune` now accepts a block that can be used to filter the messages to be pruned ([#421](https://github.com/discordrb/discordrb/pull/421), thanks @snapcase)
- WSCS verions message is now only printed when using voice functionality ([#438](https://github.com/discordrb/discordrb/pull/438), thanks @dreid)
- **(breaking change)** `API::Server.update_channel` is now `API::Server.update_channel_positions`
- CI is now tested against Ruby 2.3, 2.4, and 2.5 ([#476](https://github.com/discordrb/discordrb/pull/476), thanks @nicolasleger)
- CI now tests with YARD to validate docstrings
- Specs for `Channel` are refactored ([#481](https://github.com/discordrb/discordrb/pull/481), thanks @Daniel-Worrall)
- Specs are refactored to not use `module` namespaces ([#520](https://github.com/discordrb/discordrb/pull/520), thanks @Daniel-Worrall)
- `Bot` now logs to `LOGGER.info` when the bot successfully resumes
- Code climate tooling is updated ([#489](https://github.com/discordrb/discordrb/pull/489), thanks @PanisSupraOmnia)
- `Bot#parse_mention` will now return an `Emoji` object for a mention of an emoji the bot isn't connected to ([#473](https://github.com/discordrb/discordrb/pull/473))
- The changelog now follows the "Keep a Changelog" format ([#504](https://github.com/discordrb/discordrb/pull/504), thanks @connorshea)
- `Bot#run` documentation is adjusted to clarify the use of its async argument ([#521](https://github.com/discordrb/discordrb/pull/521))
- **(breaking change)** `Bot#join` is renamed to `Bot#accept_invite` ([#521](https://github.com/discordrb/discordrb/pull/521))
- `Embed#colour=`/`Embed#color=` now accepts instances of `ColourRGB`/`ColorRGB` ([#523](https://github.com/discordrb/discordrb/pull/523))
- `Gateway` now performs certificate validation, and enforces use of TLSv1.2. If you experience issues (please report them!), you can return to the old codepath by setting `DISCORDRB_SSL_VERIFY_NONE` ([#528](https://github.com/discordrb/discordrb/pull/528), thanks @cky)
- Documentation clarifications around `voice_state_update`, `member_update`, and `server_create` ([#531](https://github.com/discordrb/discordrb/pull/531))
- URLs listed across the code base now use https, various other cleanups ([#540](https://github.com/discordrb/discordrb/pull/540), thanks @PanisSupraOmnia)
- Dependency on the `ffi` gem is restricted to `>= 1.9.24` to prevent a security exploit on Windows, per [CVE-2018-1000201](https://nvd.nist.gov/vuln/detail/CVE-2018-1000201) ([#544](https://github.com/discordrb/discordrb/pull/544))
- Warnings about accessing cached data after server streaming times out are now clarified and printed when accessing relevant methods ([#578](https://github.com/discordrb/discordrb/pull/578), thanks @connorshea)

### Deprecated

- The existing awaits system is deprecated in favor of a simpler, synchronous system introduced in [#499](https://github.com/discordrb/discordrb/pull/499) ([#509](https://github.com/discordrb/discordrb/pull/509))

### Removed

- **(breaking change)** Unsupported `mentions` argument in Create Message API ([#420](https://github.com/discordrb/discordrb/pull/420))
- **(breaking change)** `TrueClass` is no longer an alias for `:debug` logging in `Bot#initialize`

### Fixed

- `Errors::MessageTooLong` is now raised correctly ([#325](https://github.com/discordrb/discordrb/pull/325), thanks @Daniel-Worrall)
- Certain `Reaction` related events properly inherit `Event` ([#329](https://github.com/discordrb/discordrb/pull/329), thanks @valeth)
- Permissions calculation now takes the server's `@everyone` role permissions into consideration (additional work by [#357](https://github.com/discordrb/discordrb/pull/357), thanks @mattantonelli)
- `Role#members` had a typo preventing it from working ([#340](https://github.com/discordrb/discordrb/pull/340))
- `Message#my_reactions` now correctly returns `Array<Reaction>` ([#342](https://github.com/discordrb/discordrb/pull/342))
- Several internal checks have been added to make bots more resilient to zombie connections
- Documentation for `TypingEvent` is now more accurate ([#367](https://github.com/discordrb/discordrb/pull/367), thanks @Snazzah)
- Corrected implementation of the `reason` parameter in various API ([#372](https://github.com/discordrb/discordrb/pull/372))
- `CommandBot`'s advanced functionality properly handles empty strings in certain settings ([#379](https://github.com/discordrb/discordrb/pull/379), thanks @LikeLakers2)
- Rate limit headers are processed correctly when running into certain API exceptions ([#440](https://github.com/discordrb/discordrb/pull/440), thanks @unleashy)
- Typos preventing `ArgumentError` from being raised when processing `arg_types` ([#400](https://github.com/discordrb/discordrb/pull/400), thanks @Daniel-Worrall)
- `Server#create_role` correctly accepts a `ColourRGB`/`ColorRGB` via `#combined`
- `EventContainer#add_handler` correctly adds handlers for events that haven't had internal storage created for them yet
- When a server is initially cached, its channels are now cached in a way that prevents REST exceptions from being raised when attempting to process gateway events with uncached channels as a subject ([#391](https://github.com/discordrb/discordrb/pull/391))
- Await event matching now considers specific subclasses, preventing certain awaits to be triggered wrongly on different events in the same class tree ([#431](https://github.com/discordrb/discordrb/pull/431))
- Bulk deleting messages properly filters out messages older than two weeks ([#439](https://github.com/discordrb/discordrb/pull/439), thanks @Emberwalker)
- Rate limiting when certain API errors occur are handled properly ([#440](https://github.com/discordrb/discordrb/pull/440), thanks @unleashy)
- Querying the cache for an unknown member no longer adds `nil` elements, which caused unexpected behavior ([#456](https://github.com/discordrb/discordrb/pull/456))
- Logging behaves correctly when token is an empty string ([#449](https://github.com/discordrb/discordrb/pull/449), thanks @Daniel-Worrall)
- Several typos in documentation ([#444](https://github.com/discordrb/discordrb/pull/444), thanks @ToppleKek)
- When possible, `User` objects are now cached from messages instead of making an API request that may fail
- `rest-client` is upgraded to `>= 2.1.0.rc1`, as `2.1.0` is completely broken on Windows with Ruby 2.5 ([#478](https://github.com/discordrb/discordrb/pull/478), thanks @Daniel-Worrall and @swarley)
- `EmbedAuthor` sets the correct instance variable for `proxy_icon_url`
- `ReactionEvent` correctly returns the server on which it occurred ([#484](https://github.com/discordrb/discordrb/pull/484), thanks @charagarlnad)
- `ServerRoleCreateEvent` no longer fails to match when supplying a `name` attribute ([#493](https://github.com/discordrb/discordrb/pull/493), [#506](https://github.com/discordrb/discordrb/pull/506), thanks @Daniel-Worrall and @micke)
- `PlayingEvent` now correctly returns `server` ([#486](https://github.com/discordrb/discordrb/pull/486), thanks @xTVaser)
- Roles will no longer be cached twice when using `Server#create_role` ([#488](https://github.com/discordrb/discordrb/pull/488))
- Race condition when creating event handlers inside of other event handlers ([#514](https://github.com/discordrb/discordrb/pull/514))
- Command chain execution is halted immediately if `execute_command` fails, fixing some possible errors that could occur with `advanced_functionality` ([#517](https://github.com/discordrb/discordrb/pull/517), thanks @unleashy)
- In the event non-existent role IDs are observed in a member object, they are ignored to prevent cache related errors ([#535](https://github.com/discordrb/discordrb/pull/535))
- `end_with` attribute in `MessageEventHandler` now accepts group-less regular expressions without throwing exceptions ([#571](https://github.com/discordrb/discordrb/pull/571), thanks @badBlackShark)
- `PresenceEvent` is correctly raised when dispatched ([#574](https://github.com/discordrb/discordrb/pull/574))
- `Attachment#initialize` correctly sets `@id` instance variable ([#575](https://github.com/discordrb/discordrb/pull/575), thanks @kandayo)

## [3.2.1] - 2017-02-18
[3.2.1]: https://github.com/discordrb/discordrb/releases/tag/v3.2.1

[View diff for this release.](https://github.com/discordrb/discordrb/compare/v3.2.0.1...v3.2.1)

### Changed
- `Bot#stop` and `Gateway#stop` now explicitly return `nil`, for more convenient use in commands
- The API method to query for users has been removed as the endpoint no longer exists
- Some more methods have been changed to resolve IDs, which means they can be called with integer and string IDs instead of just the objects ([#313](https://github.com/discordrb/discordrb/pull/313), thanks @LikeLakers2)
- Bulk deleting now uses the new non-deprecated URL – this has no immediate effect, but once the old one will be removed bots using it will not be able to bulk delete anymore (see also [#309](https://github.com/discordrb/discordrb/issues/309))

### Fixed
- Fixed another bug with resumes that caused issues when resuming a zombie connection
- Fixed a bug that caused issues when playing short files ([#326](https://github.com/discordrb/discordrb/issues/316))

## [3.2.0.1] - 2017-01-29
[3.2.0.1]: https://github.com/discordrb/discordrb/releases/tag/v3.2.0.1

[View diff for this release.](https://github.com/discordrb/discordrb/compare/v3.2.0...v3.2.0.1)

### Fixed
- Attempt to fix an issue that causes a strange problem with dependencies when installing discordrb

## [3.2.0] - 2017-01-29
[3.2.0]: https://github.com/discordrb/discordrb/releases/tag/v3.2.0

[View diff for this release.](https://github.com/discordrb/discordrb/compare/v3.1.1...v3.2.0)

### Added
- Various parts of gateway error handling were improved, leading to significant stability improvements:
  - A long standing bug was fixed that prevented resumes in most cases, which caused unnecessary reconnections.
  - The error handler that handles problems with sending the raw data over TCP now catches errors more broadly.
  - Heartbeat ACKs (opcode 11) are now checked, which allows the client to detect zombie connections early on. If this causes problems for you you can disable it using `bot.gateway.check_heartbeat_acks = false`.
  - Received heartbeats are now properly handled again
- Added a client for webhooks, implemented as a separate gem `discordrb-webhooks`. This allows the creation of applications that only use webhooks without the overhead provided by the rest of discordrb. The gem is added as a dependency by normal discordrb so you don't need to install it separately if you're already using that.
- Adding, updating or deleting custom emoji is now supported ([#285](https://github.com/discordrb/discordrb/pull/285), thanks @Daniel-Worrall)
- Rich embeds can now be sent alongside messages, for example using the `embed` parameter in `send_message`, or with the new method `Channel#send_embed`
- `advanced_functionality` bots now support escaping using backslashes ([#293](https://github.com/discordrb/discordrb/issues/293) / [#304](https://github.com/discordrb/discordrb/pull/304), thanks @LikeLakers2)
- Added type checking and conversion for commands ([#298](https://github.com/discordrb/discordrb/pull/298), thanks @ohtaavi)
- Bulk deleting messages now checks for message age (see also [discordapp/discord-api-docs#208](https://github.com/discordapp/discord-api-docs/issues/208)). By default, it will ignore messages that are too old to be bulk deleted, but there is also a `strict` mode setting now that raises an exception in such a case.
- Reactions can now be viewed for existing messages ([#262](https://github.com/discordrb/discordrb/pull/262), thanks @z64), added to messages ([#266](https://github.com/discordrb/discordrb/pull/266), thanks @z64), and listened for using gateway events as well as internal handlers ([#300](https://github.com/discordrb/discordrb/issues/300)).
- Game types and stream URLs are now cached ([#297](https://github.com/discordrb/discordrb/issues/297))
- The default non-streaming game was changed to be `0` instead of `nil` ([#277](https://github.com/discordrb/discordrb/pull/277), thanks @zeyla)
- A method `Channel#delete_message` was added to support deleting single messages by ID without prior resolution.
- Permission overwrites can now be deleted from channels ([#268](https://github.com/discordrb/discordrb/pull/268), thanks @greenbigfrog)
- There is now a utility method `IDObject.synthesise` that creates snowflakes with specific timestamps out of thin air.
- Typing events are now respondable, so you can call `#respond` on them for example ([#270](https://github.com/discordrb/discordrb/pull/270), thanks @VxJasonxV)
- Message authors can now be `User` objects if a `Member` object could not be found or created ([#290](https://github.com/discordrb/discordrb/issues/290))
- Added two new events, `unknown` ([#288](https://github.com/discordrb/discordrb/issues/288)) and `raw`, that are raised for unknown dispatches and all dispatches, respectively.
- Bots can now be set to fully ignore other bots ([#257](https://github.com/discordrb/discordrb/pull/257), thanks @greenbigfrog)
- Voice state update events now have an `old_channel` property/attribute that denotes the previous channel the user was in in case of joining/moving/leaving.
- The default help command no longer shows commands the user can't use ([#275](https://github.com/discordrb/discordrb/pull/275), thanks @FormalHellhound)
- Updated the command example to no longer include user-specific stuff ([#260](https://github.com/discordrb/discordrb/issues/260))
- `Server#role` now resolves IDs, so they can be passed as strings if necessary.

### Fixed
- Fixed bots' shard settings being ignored in certain cases
- Parsing role mentions using `Bot#parse_mention` works properly now.
- Fixed some specific REST methods that were broken by the API module refactor ([#302](https://github.com/discordrb/discordrb/pull/302), thanks @LikeLakers2)
- Cached channel data is now updated properly on change ([#272](https://github.com/discordrb/discordrb/issues/272))
- Users' avatars are now updated properly on change ([#265](https://github.com/discordrb/discordrb/pull/265), thanks @Roughsketch)
- Fixed voice state tracking for newly created channels ([#292](https://github.com/discordrb/discordrb/issues/292))
- Fixed event attribute handling for PlayingEvent ([#303](https://github.com/discordrb/discordrb/pull/303), thanks @sven-strothoff)
- Getting specific emoji by ID no longer fails to resolve non-cached emoji ([#283](https://github.com/discordrb/discordrb/pull/283), thanks @greenbigfrog)
- Voice state update events no longer fail to be raised for users leaving channels, if the event handler had a channel attribute set ([#301](https://github.com/discordrb/discordrb/issues/301))
- Bots that don't define any events should work properly again
- Fixed error handling for messages over the character limit ([#276](https://github.com/discordrb/discordrb/issues/276))
- Fixed some specific log messages not being called properly ([#263](https://github.com/discordrb/discordrb/pull/263), thanks @Roughsketch)
- Fixed some edge case bugs in the default help command:
  - In the case of too many commands to be sent in the channel, it no longer replies with "Sending help in PM!" when called from PM
  - It no longer fails completely if called from PM if there are any commands that require server-specific checks ([#308](https://github.com/discordrb/discordrb/issues/308))
  - Fixed a slight formatting mistake
- Quoted command arguments in `advanced_functionality` are no longer split by newline
- Fixed a specific edge case in command chain handling where handling commands with the same name as the chain delimiter was broken

## [3.1.1] - 2016-10-21
[3.1.1]: https://github.com/discordrb/discordrb/releases/tag/v3.1.1

[View diff for this release.](https://github.com/discordrb/discordrb/compare/v3.1.0...v3.1.1)

### Fixed
- An oversight where a `GUILD_DELETE` dispatch would cause an internal error was fixed. ([#256](https://github.com/discordrb/discordrb/pull/256), thanks @greenbigfrog)

## [3.1.0] - 2016-10-20
[3.1.0]: https://github.com/discordrb/discordrb/releases/tag/v3.1.0

[View diff for this release.](https://github.com/discordrb/discordrb/compare/v3.0.2...v3.1.0)

### Added
- Emoji handling support ([#226](https://github.com/discordrb/discordrb/pull/226), thanks @greenbigfrog)
- A `channels` attribute has been added to `CommandBot` as well as `Command` to restrict the channels in which either of the two works ([#249](https://github.com/discordrb/discordrb/pull/249), thanks @Xzanth)
- The bulk deletion endpoint is now exposed directly using the `Channel#delete_messages` method ([#235](https://github.com/discordrb/discordrb/pull/235), thanks @z64)
- The internal settings fields for user statuses that cause statuses to persist across restarts can now be modified ([#233](https://github.com/discordrb/discordrb/pull/233), thanks @Daniel-Worrall)
- A few examples have been added to the docs ([#250](https://github.com/discordrb/discordrb/pull/250), thanks @SunDwarf)
- The specs have been improved; they're still not exhaustive by far but there are at least slightly more now.

### Fixed
- Fixed an important bug that caused the logger not to work in some cases. ([#243](https://github.com/discordrb/discordrb/pull/243), thanks @Daniel-Worrall)
- Fixed logger token redaction.
- `unavailable_servers` should no longer crash the bot due to being nil in some cases ([#244](https://github.com/discordrb/discordrb/pull/244), thanks @Daniel-Worrall)
- `Profile#on` for member resolution is now no longer overwritten by an alias for `#online` ([#247](https://github.com/discordrb/discordrb/pull/247), thanks @Daniel-Worrall)
- A `CommandBot` without any commands should no longer crash when receiving a message that triggers it ([#242](https://github.com/discordrb/discordrb/issues/242))
- Changing nicknames works again, it has apparently been broken in 3.0.0.

## [3.0.2] - 2016-10-07
[3.0.2]: https://github.com/discordrb/discordrb/releases/tag/v3.0.2

[View diff for this release.](https://github.com/discordrb/discordrb/compare/v3.0.1...v3.0.2)

### Changed
- A small change to how CommandBot parameter lists are formatted ([#240](https://github.com/discordrb/discordrb/pull/240), thanks @FormalHellhound)

### Fixed
- Setting properties on a channel (e.g. `Channel#topic=`) works again ([#238](https://github.com/discordrb/discordrb/issues/238) / [#239](https://github.com/discordrb/discordrb/pull/239), thanks @Daniel-Worrall)

## [3.0.1] - 2016-10-01
[3.0.1]: https://github.com/discordrb/discordrb/releases/tag/v3.0.1

[View diff for this release.](https://github.com/discordrb/discordrb/compare/v3.0.0...v3.0.1)

A tiny update to support webhook-sent messages properly!

### Added
- Added the utility methods `Message#webhook?` and `User#webhook?` to check whether a message or a user belongs to a webhook
- Added `Message#webhook_id` to get the ID of the sending webhook for webhook messages
- Added the `webhook_commands` parameter to CommandBot that, if false (default true), prevents webhook-sent messages from being parsed and handled as commands.

### Fixed
- Fixed webhook-sent messages being ignored because their author couldn't be resolved.
- Fixed a minor performance problem where a CommandBot would create unnecessarily create redundant objects for every received message.

## [3.0.0] - 2016-09-30
[3.0.0]: https://github.com/discordrb/discordrb/releases/tag/v3.0.0

[View diff for this release.](https://github.com/discordrb/discordrb/compare/v2.1.3...v3.0.0)

I didn't think there could possibly be a release larger than 2.0.0 was, but here it is! Including the respective release commit, there were 540 commits from 1.8.1 to 2.0.0, but a whopping 734 commits from 2.1.3 to 3.0.0.

As with 2.0.0, there are some breaking changes! They are, as always, highlighted in bold.

### Added
- **The `application_id` parameter has been renamed to `client_id`**. With the changes to how bot applications work, it would just be confusing to have it be called `application_id` any longer. If you try to use `application_id` now, it will raise a descriptive exception; with 3.1.0 that will be removed too (you'll get a less descriptive exception).
- The gateway implementation has been completely rewritten, for more performance, stability and maintainability. This means that **to call some internal methods like `inject_reconnect`, a `Gateway` instance (available as `Bot#gateway`) now needs to be used.**
- **User login using email and password has been removed**. Use a user token instead, see also [here](https://github.com/discordapp/discord-api-docs/issues/69#issuecomment-223886862).
- In addition to the rewrite, the gateway version has also been upgraded to protocol version 6 (the rewrite was for v5). **With this, the way channel types are handled has been changed a bit!** If you've been using the abstraction methods like `Channel#voice?`, you should be fine though. This also includes support for group chats on user accounts, as that was the only real functionality change on v6. ([#211](https://github.com/discordrb/discordrb/pull/211), thanks @Daniel-Worrall)
- **Custom prefix handlers for `CommandBot`s now get the full message object as their parameter rather than only the content**, for even more flexibility.
- For internal consistency, **the `UnknownGuild` error was renamed to `UnknownServer`**. I doubt this change affects anyone, but if you handle that error specifically in your bot, make sure to change it.
- **The API module has undergone a refactor**, if you were using any manual API calls you will have to update them to the new format. Specifically, endpoints dealing with channels have been moved to `API::Channel`, ones dealing with users to `API::User` and so on. ([#203](https://github.com/discordrb/discordrb/pull/203), thanks @depl0y)
- **Calling `users` on a text channel will now only return users who have permission to read it** ([#186](https://github.com/discordrb/discordrb/issues/186))
- A variety of new fields have been added to `Message` objects, specifically embeds (`Message#embeds`), when it was last edited (`#edited_timestamp`), whether it uses TTS (`#tts?`), its nonce (`#nonce`), whether it was ever edited (`#edited?`), and whether it mentions everyone (`mention_everyone?`) ([#206](https://github.com/discordrb/discordrb/pull/206), thanks @SnazzyPine25)
- A variety of new functionality has been added to `Server` and `Channel` objects ([#181](https://github.com/discordrb/discordrb/pull/181), thanks @SnazzyPine25):
  - Bitrate and user limit can now be read and set for voice channels
  - Server integrations can now be read
  - Server features and verification level can now be read
  - Utility functions to generate widget, widget banner and splash URLs
- Message pinning is now supported, both reading pin status and pinning existing messages ([#145](https://github.com/discordrb/discordrb/issues/145) / [#146](https://github.com/discordrb/discordrb/pull/146), thanks @hlaaftana)
- Support for the new available statuses:
  - `Bot#dnd` to make the bot show up as DnD (red dot)
  - `Bot#invisible` to make the bot show up as offline
- Setting the bot's status to streaming is now supported ([#128](https://github.com/discordrb/discordrb/pull/128) and [#143](https://github.com/discordrb/discordrb/pull/143), thanks @SnazzyPine25 and @barkerja)
- You can now set a message to be sent when a `CommandBot`'s command fails with a `NoPermission` error ([#200](https://github.com/discordrb/discordrb/pull/200), thanks @PoVa)
- There is now an optional field to list the parameters a command can accept ([#201](https://github.com/discordrb/discordrb/pull/201), thanks @FormalHellhound)
- Commands can now have an array of roles set that are required to be able to use it ([#178](https://github.com/discordrb/discordrb/pull/178), thanks @PoVa)
- Methods like `CommandEvent#<<` for quickly responding to an event are now available in `MessageEvent` too ([#154](https://github.com/discordrb/discordrb/pull/154), thanks @hlaaftana)
- Temporary messages, that automatically delete after some time, can now be sent to channels ([#136](https://github.com/discordrb/discordrb/issues/136) / [#139](https://github.com/discordrb/discordrb/pull/139), thanks @unleashy)
- Captions can now be sent together with files, and files can be attached to events to be sent on completion ([#130](https://github.com/discordrb/discordrb/pull/130), thanks @SnazzyPine25)
- There is now a `Channel#load_message` method to get a single message by its ID ([#174](https://github.com/discordrb/discordrb/pull/174), thanks @z64)
- `Channel#define_overwrite` can now be used with a `Profile` object, together with some internal changes ([#232](https://github.com/discordrb/discordrb/issues/232))
- There are now endpoint methods to list a server's channels and channel invites ([#197](https://github.com/discordrb/discordrb/pull/197))
- Two methods, `Member#roles=` and `Member#modify_roles` to manipulate a member's roles in a more advanced way have been added ([#223](https://github.com/discordrb/discordrb/pull/223), thanks @z64)
- Role mentionability can now be set using `Role#mentionable=`
- The current bot's OAuth application can now be read ([#175](https://github.com/discordrb/discordrb/pull/175), thanks @SnazzyPine25)
- You can now mute and deafen other members ([#157](https://github.com/discordrb/discordrb/pull/157), thanks @SnazzyPine25)
- The internal `Logger` now supports writing to a file instead of STDOUT ([#171](https://github.com/discordrb/discordrb/issues/171))
  - Building on top of that, you can also write to multiple streams at the same time now, in case you want to have input on both a file and STDOUT, or even more advanced setups. ([#217](https://github.com/discordrb/discordrb/pull/217), thanks @PoVa)
- Roles can now have their permissions bitfield set directly ([#177](https://github.com/discordrb/discordrb/issues/177))
- The `Bot#invite_url` method now supports adding permission bits into the generated URL ([#218](https://github.com/discordrb/discordrb/pull/218), thanks @PoVa)
- A utility method `User#send_file` has been added to directly send a file to a user in PM ([#168](https://github.com/discordrb/discordrb/issues/168) / [#172](https://github.com/discordrb/discordrb/pull/172), thanks @SnazzyPine25)
- You can now get the list of members that have a particular role assigned using `Role#members` ([#147](https://github.com/discordrb/discordrb/pull/147), thanks @hlaaftana)
- You can now check whether a `VoiceBot` is playing right now using `#playing?` ([#137](https://github.com/discordrb/discordrb/pull/137), thanks @SnazzyPine25)
- You can now get the channel a `VoiceBot` is playing on ([#138](https://github.com/discordrb/discordrb/pull/138), thanks @snapcase)
- The permissions bit map has been updated for emoji, "Administrator" and nickname changes ([#180](https://github.com/discordrb/discordrb/pull/180), thanks @megumisonoda)
- A method `Bot#connected?` has been added to check whether the bot is currently connected to the gateway.
- The indescriptive error message that was previously sent when calling methods like `Bot#game=` without an active gateway connection has been replaced with a more descriptive one.
- The bot's token is now, by default, redacted from any logging output; this can be turned off if desired using the `redact_token` initialization parameter. ([#225](https://github.com/discordrb/discordrb/issues/225) / [#231](https://github.com/discordrb/discordrb/pull/231), thanks @Daniel-Worrall)
- The new rate limit headers are now supported. This will have no real impact on any code using discordrb, but it means discordrb is now considered compliant again. See also [here](https://github.com/discordapp/discord-api-docs/issues/108).
- Rogue presences, i.e. presences without an associated cached member, now print a log message instead of being completely ignored
- A variety of aliases have been added to existing methods.
- An example to show off voice sending has been added to the repo, and existing examples have been improved.
- A large amount of fixes and clarifications have been made to the docs.

### Fixed
- The almost a year old bug where changing the own user's username would reset its avatar has finally been fixed.
- The issue where resolving a large server with the owner offline would sometimes cause a stack overflow has been fixed ([#169](https://github.com/discordrb/discordrb/issues/169) / [#170](https://github.com/discordrb/discordrb/issues/170) / [#191](https://github.com/discordrb/discordrb/pull/191), thanks @stoodfarback)
- Fixed an issue where if a server had an AFK channel set, but that AFK channel couldn't be connected to, resolving the server (and in turn all objects depending on it) would fail. This likely fixes any random `NoPermission` errors you've ever encountered in your log.
- A message's author will be resolved over the REST API like other objects in case it's not cached yet. This should fix all instances of "Member not cached even thought it should be". ([#210](https://github.com/discordrb/discordrb/pull/210), thanks @megumisonoda)
- Voice state handling has been completely redone, fixing a variety of caching issues. ([#159](https://github.com/discordrb/discordrb/issues/159))
- Getting a voice channel's users no longer does a chunk request ([#142](https://github.com/discordrb/discordrb/issues/142))
- `Channel#define_overwrite` can now be used to define user overwrites, apparently that didn't work at all before
- Nested command chains where an inner command doesn't exist now no longer crash the command chain handler ([#215](https://github.com/discordrb/discordrb/issues/215))
- Gateway errors should no longer spam the console ([#141](https://github.com/discordrb/discordrb/issues/141) / [#148](https://github.com/discordrb/discordrb/pull/148), thanks @meew0)
- Role hoisting (both setting and reading it) should now work properly
- The `VoiceBot#stop_playing` method should now work more predictably
- Voice states with a nil channel should no longer crash when accessed ([#183](https://github.com/discordrb/discordrb/pull/183), thanks @Apexal)
- A latent bug in how PM channels were cached is fixed, previously they were cached twice - once by channel ID and once by recipient ID. Now they're only cached by recipient ID.
- Two problems in how Discord outages are handled are now fixed; the bot should now no longer break when one happens. Specifically, the fixed problems are:
  - `GUILD_DELETE` events for unavailable servers are now ignored
  - Opcode 9 packets which are received while no session currently exists are handled correctly
- A possible regression in PM channel creation was fixed. ([#227](https://github.com/discordrb/discordrb/issues/227) / [#228](https://github.com/discordrb/discordrb/pull/228), thanks @heimidal)

## [2.1.3] - 2016-06-11
[2.1.3]: https://github.com/discordrb/discordrb/releases/tag/v2.1.3

[View diff for this release.](https://github.com/discordrb/discordrb/compare/v2.1.2...v2.1.3)

### Fixed
- Various messages that were just printed to stdout that should have been using the `Logger` system now do ([#132](https://github.com/discordrb/discordrb/issues/132) and [#133](https://github.com/discordrb/discordrb/pull/133), thanks @PoVa)
- A mistake in the documentation was fixed ([#140](https://github.com/discordrb/discordrb/issues/140))
- Handling of the `GUILD_MEMBER_DELETE` gateway event should now work even if, for whatever reason, Discord sends an invalid server ID ([#129](https://github.com/discordrb/discordrb/issues/129))
- If the processing of a particular voice packet takes too long, the user will now be warned instead of an error being raised ([#134](https://github.com/discordrb/discordrb/issues/134))

## [2.1.2] - 2016-05-29
[2.1.2]: https://github.com/discordrb/discordrb/releases/tag/v2.1.2

[View diff for this release.](https://github.com/discordrb/discordrb/compare/v2.1.1...v2.1.2)

### Added
- A reader was added (`Bot#awaits`) to read the hash of awaits, so ones that aren't necessary anymore can be deleted.
- `Channel#prune` now uses the bulk delete endpoint which means it will be much faster and no longer rate limited ([#118](https://github.com/discordrb/discordrb/pull/118), thanks @snapcase)

### Fixed
- A few unresolved links in the documentation were fixed.
- The tracking of streamed servers was updated so that very long lists of servers should now all be processed.
- Resolution methods now return nil if the object to resolve can't be found, which should alleviate some rare caching problems ([#124](https://github.com/discordrb/discordrb/pull/124), thanks @Snazzah)
- In the rare event that Discord sends a voice state update for a nonexistent member, there should no longer be a gateway error ([#125](https://github.com/discordrb/discordrb/issues/125))
- Network errors (`EPIPE` and the like) should no longer cause an exception while processing ([#127](https://github.com/discordrb/discordrb/issues/127))
- Uncached members in messages are now logged.

## [2.1.1] - 2016-05-08
[2.1.1]: https://github.com/discordrb/discordrb/releases/tag/v2.1.1

[View diff for this release.](https://github.com/discordrb/discordrb/compare/v2.1.0...v2.1.1)

### Fixed
- Fixed a caching error that occurred when deleting roles ([#113](https://github.com/discordrb/discordrb/issues/113))
- Commands should no longer be triggered with nil authors ([#114](https://github.com/discordrb/discordrb/issues/114))

## [2.1.0] - 2016-04-30
[2.1.0]: https://github.com/discordrb/discordrb/releases/tag/v2.1.0

[View diff for this release.](https://github.com/discordrb/discordrb/compare/v2.0.4...v2.1.0)

### Added
- API support for the April 29 Discord update, which was the first feature update in a while with more than a few additions to the API, was added. This includes: ([#111](https://github.com/discordrb/discordrb/pull/111))
  - Members' nicknames can now be set and read (`Member#nick`) and updates to them are being tracked.
  - Roles now have a `mentionable?` property and a `mention` utility method.
  - `Message` now tracks a message's role mentions.
- The internal REST rate limit handler was updated:
  - It now tracks message rate limits server wide to properly handle new bot account rate limits. ([#100](https://github.com/discordrb/discordrb/issues/100))
  - It now keeps track of all requests, even those that are known not to be rate limited (it just won't do anything to them). This allows for more flexibility should future rate limits be added.
- Guild sharding is now supported using the optional `shard_id` and `num_shards` to bot initializers. Read about it here: https://github.com/discordapp/discord-api-docs/issues/17 ([#98](https://github.com/discordrb/discordrb/issues/98))
- Commands can now require users to have specific action permissions to be able to execute them using the `:required_permissions` attribute. ([#104](https://github.com/discordrb/discordrb/issues/104) / [#112](https://github.com/discordrb/discordrb/pull/112))
- A `heartbeat` event was added that gets triggered every now and then to allow for roughly periodic actions. ([#110](https://github.com/discordrb/discordrb/pull/110))
- Prefixes are now more flexible in the format they can have - arrays and callables are now allowed as well. Read the documentation for more info.([#107](https://github.com/discordrb/discordrb/issues/107) / [#109](https://github.com/discordrb/discordrb/pull/109))

## [2.0.4] - 2016-04-19
[2.0.4]: https://github.com/discordrb/discordrb/releases/tag/v2.0.4

[View diff for this release.](https://github.com/discordrb/discordrb/compare/v2.0.3...v2.0.4)

### Added
- Added a utility method `Invite#url` ([#86](https://github.com/discordrb/discordrb/issues/86)/[#101](https://github.com/discordrb/discordrb/pull/101), thanks @PoVa)

### Fixed
- Fix a caching inconsistency where a server's channels and a bot's channels wouldn't be identical. This caused server channels to not update properly ([#105](https://github.com/discordrb/discordrb/issues/105))
- Setting avatars should now work again on Windows ([#96](https://github.com/discordrb/discordrb/issues/96))
- Message edit events should no longer be raised with nil authors ([#95](https://github.com/discordrb/discordrb/issues/95))
- Invites can now be created again ([#87](https://github.com/discordrb/discordrb/issues/87))
- Voice states are now preserved for chunked members, fixes an issue where a voice channel's users would ignore all voice states that occurred before the call ([#103](https://github.com/discordrb/discordrb/issues/103))
- Fixed some possible problems with heartbeats not being sent with unstable connections

## [2.0.3] - 2016-04-15
[2.0.3]: https://github.com/discordrb/discordrb/releases/tag/v2.0.3

[View diff for this release.](https://github.com/discordrb/discordrb/compare/v2.0.2...v2.0.3)

### Added
- All examples now fully use v2 ([#92](https://github.com/discordrb/discordrb/pull/92), thanks @snapcase)
- The message that occurs when a command is missing permission can now be changed or disabled ([#94](https://github.com/discordrb/discordrb/pull/94), thanks @snapcase)
- The log message that occurs when you disconnect from the WebSocket is now more compact ([#90](https://github.com/discordrb/discordrb/issues/90))
- `Bot#ignored?` now exists to check whether a user is ignored

### Fixed
- A problem where getting channel history would sometimes cause an exception has been fixed ([#88](https://github.com/discordrb/discordrb/issues/88))
- `split_message` should now behave correctly in a specific edge case ([#85](https://github.com/discordrb/discordrb/pull/85), thanks @AnhNhan)
- DCA playback should no longer cause an error when playback ends due to a specific reason

## [2.0.2] - 2016-04-10
[2.0.2]: https://github.com/discordrb/discordrb/releases/tag/v2.0.2

[View diff for this release.](https://github.com/discordrb/discordrb/compare/v2.0.1...v2.0.2)

### Added
- Added `Server#text_channels` and `#voice_channels` ([#79](https://github.com/discordrb/discordrb/issues/79))
- Added `Server#online_users` ([#80](https://github.com/discordrb/discordrb/issues/80))
- Added `Member#role?` ([#83](https://github.com/discordrb/discordrb/issues/83))
- Added three utility methods `User#online?`, `#offline?`, and `#idle?`
- `Bot#send_message` can now take channel objects as well as the ID

### Fixed
- Removing the bot from a server will no longer result in a gateway message error
- Fixed an exception raised if a previously unavailable guild goes online after the stream timeout
- `server_create` will no longer be raised for newly available guilds
- Fixed the annoying message about constant reassignment at startup
- Fixed an error where rarely a server's owner wouldn't be initialized correctly

## [2.0.1] - 2016-04-10
[2.0.1]: https://github.com/discordrb/discordrb/releases/tag/v2.0.1

[View diff for this release.](https://github.com/discordrb/discordrb/compare/v2.0.0...v2.0.1)

### Added
- Added some more examples ([#75](https://github.com/discordrb/discordrb/pull/75), thanks @greenbigfrog)
- Users can now be ignored from messages at gateway level (`Bot#ignore_user`, `Bot#unignore_user`)
- `Member#add_role` and `Member#remove_role` were re-added from User - they were missing before

### Fixed
- Fixed some typos in the documentation
- If a server is actually unavailable it will no longer spam the console with timeout messages
- VoiceBot now sends five frames of silence after finishing a track. This fixes an issue where the sound from the last track would bleed over into the new one due to interpolation.
- Fixed a bug where playing something right after connecting to voice would sometimes cause the encryption key to not be set

## [2.0.0] - 2016-04-08
[2.0.0]: https://github.com/discordrb/discordrb/releases/tag/v2.0.0

[View diff for this release.](https://github.com/discordrb/discordrb/compare/v1.8.1...v2.0.0)

### Added
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
 - `Message`s returned at the end of commands (for example using `User#pm` or `Message#edit`) will now no longer be sent ([#66](https://github.com/discordrb/discordrb/issues/66))
 - The `:with_text` event attribute is now aliased to `:exact_text` ([#65](https://github.com/discordrb/discordrb/issues/65))
 - Server icons (`Server#icon=`) can now be set just like avatars (`Profile#avatar=`)
 - Lots of comments were added to the examples and some bugs fixed
 - The overall performance and memory usage was improved, especially on Ruby 2.3 (using the new frozen string literal comment)
 - The documentation was slightly improved.

### Fixed
- A *lot* of latent bugs with caching were fixed. This doesn't really have a noticeable effect, it just means better stability and reliability as a whole.
- **Command bots no longer respond when there are spaces between the prefix and the command.** Because this behaviour may be desirable, a `spaces_allowed` attribute was added to the CommandBot initializer that can be set to true to re-enable this behaviour.
- Permission calculation (`User#permission?`) has been thoroughly rewritten and should now account for edge cases like server owners and Manage Permissions.
- The gateway reconnect logic now uses a correct falloff system - before it would start at 1 second between attempts and immediately jump to 120. Now the transition is more smooth.
- Commands with aliases now show up correctly in the auto-generated help command ([#72](https://github.com/discordrb/discordrb/issues/72))
- The auto-generated help command can now actually be disabled by setting the corresponding attribute to nil ([#73](https://github.com/discordrb/discordrb/issues/73))
- Including empty containers now does nothing instead of raising an error
- Command bots now obey `should_parse_self`

## [1.8.1] - 2016-03-11
[1.8.1]: https://github.com/discordrb/discordrb/releases/tag/v1.8.1

[View diff for this release.](https://github.com/discordrb/discordrb/compare/v1.8.0...v1.8.1)

### Fixed
* Fixed an error (caused by an undocumented API change) that would write a traceback to the console every time someone started typing in a channel invisible to the bot.

## [1.8.0] - 2016-03-11
[1.8.0]: https://github.com/discordrb/discordrb/releases/tag/v1.8.0

[View diff for this release.](https://github.com/discordrb/discordrb/compare/v1.7.5...v1.8.0)

### Added
* The built-in logger has been somewhat redone.
  * It now has a fancy mode, settable using `Discordrb::LOGGER.fancy = true/false`, that makes use of ANSI escape codes to prettify the log output.
  * It now supports more things than just `debug`, there's also `warn`, `error`, `good`, `info`, `in`, and `out`.
  * You now have finer control over what gets output, using `Discordrb::LOGGER.mode=` which accepts one of `:debug`, `:verbose`, `:normal`, `:quiet`, `:silent`.
* You can now log in with just a token by setting the email parameter to `:token` and the password to the token you want to log in with.
* DCA playback now supports `DCA1`.
* All data classes (now generalized using the `IDObject` mixin) have a `creation_date` parameter that specifies when the object was created.
* `Channel#mention` was added that mentions a channel analogous to `User#mention`.
* The aliases `tag` and `discord_tag` have been added to the discriminator because that's what Discord calls them now.

### Fixed
* A problem some users had where voice playback would leak FFmpeg processes has been fixed.
* The VWS internal thread now has a name in debug messages (`vws-i`)
* Users' voice channels should now always be set if they are in one

## [1.7.5] - 2016-03-03
[1.7.5]: https://github.com/discordrb/discordrb/releases/tag/v1.7.5

[View diff for this release.](https://github.com/discordrb/discordrb/compare/v1.7.4...v1.7.5)

### Changed
* `Channel#send_message` and `Bot#send_message` now have an extra `tts` parameter (false by default) to specify whether the message should use TTS.

### Fixed
* Attempting to `p` a data class, especially a `User` or `Profile`, should no longer lock up the interpreter due to very deep recursion.
* Manual TTS using `API.send_message` will now work correctly.

## [1.7.4] - 2016-02-28
[1.7.4]: https://github.com/discordrb/discordrb/releases/tag/v1.7.4

[View diff for this release.](https://github.com/discordrb/discordrb/compare/v1.7.3...v1.7.4)

### Added
* Added methods `Channel#text?` and `Channel#voice?` to check a channel's type.
* Frequently allocated strings have been turned into symbols or frozen constants, this should improve performance slightly.

### Fixed
* `VoiceBot#destroy` will now properly disconnect you and should no longer cause segfaults.
* Fixed a bug where you couldn't set any settings on a role created using `Server#create_role`.
* Fixed `Profile#avatar=` doing absolutely nothing.

## [1.7.3] - 2016-02-27
[1.7.3]: https://github.com/discordrb/discordrb/releases/tag/v1.7.3

[View diff for this release.](https://github.com/discordrb/discordrb/compare/v1.7.2...v1.7.3)

### Added
* The server banlist can now be accessed more nicely using `Server#bans`.
* Some abstractions for OAuth application creation were added - `bot.create_oauth_application` and `bot.update_oauth_application`. See the docs about how to use them.

## [1.7.2] - 2016-02-25
[1.7.2]: https://github.com/discordrb/discordrb/releases/tag/v1.7.2

[View diff for this release.](https://github.com/discordrb/discordrb/compare/v1.7.1...v1.7.2)

### Changed
* The `bot` object can now be read from all events, not just from command ones.
* You can now set the `filter_volume` on VoiceBot, which corresponds to the old way of doing volume handling, in case the new way is too slow for you.

## [1.7.1] - 2016-02-23
[1.7.1]: https://github.com/discordrb/discordrb/releases/tag/v1.7.1

[View diff for this release.](https://github.com/discordrb/discordrb/compare/v1.7.0...v1.7.1)

### Added
* A `clear!` method was added to EventContainer that removes all events from it, so you can overwrite modules by defining them again. (It's unnecessary for CommandContainers because commands can never be duplicate.)

### Fixed
* The tokens will now be verified correctly when obtained from the cache. (I messed up last time)
* Events of the same type in different containers will now be merged correctly when including both containers.
* Got rid of the annoying `undefined method 'game' for nil:NilClass` error that sometimes occurred on startup. (It was harmless but now it's gone entirely)

## [1.7.0] - 2016-02-23
[1.7.0]: https://github.com/discordrb/discordrb/releases/tag/v1.7.0

[View diff for this release.](https://github.com/discordrb/discordrb/compare/v1.6.6...v1.7.0)

### Added
* **`bot.find` and `bot.find_user` have had their fuzzy search feature removed because it only caused problems. If you still need it, you can copy the code from the repo's history.** In addition, `find` was renamed to `find_channel` but still exists as a (deprecated) alias.
* The in-line documentation using Yard is now complete and can be [accessed at RubyDoc](https://www.rubydoc.info/github/discordrb/discordrb/master/). It's not quite polished yet and some things may be confusing, but it should be mostly usable.
* Events and commands can now be thoroughly modularized using a system I call 'containers'. (TODO: Add a tutorial here later)
* Support for the latest API changes:
  * `Server.leave` does something different than `Server.delete`
  * The WebSocket connection now uses version 3 of the protocol
* Voice bots now support playing DCA files using the [`play_dca`](https://www.rubydoc.info/github/discordrb/discordrb/master/Discordrb%2FVoice%2FVoiceBot%3Aplay_dca) method. (TODO: Add a section to the voice tutorial)
* The [volume](https://www.rubydoc.info/github/discordrb/discordrb/master/Discordrb%2FVoice%2FVoiceBot%3Avolume) of a voice bot can now be changed during playback and not only for future playbacks.
* A `Channel.prune` method was added to quickly delete lots of messages from a channel. (It appears that this is something lots of bots do.)
* [`Server#members`](https://www.rubydoc.info/github/discordrb/discordrb/master/Discordrb%2FServer%3Amembers) is now aliased to `users`.
* An attribute [`Server#member_count`](https://www.rubydoc.info/github/discordrb/discordrb/master/Discordrb%2FServer%3Amember_count) was added that is accurate even if chunked members have not been added yet.
* An attribute [`Server#large?`](https://www.rubydoc.info/github/discordrb/discordrb/master/Discordrb%2FServer%3Alarge) was added that is true if a server could possibly have an inaccurate list of members.
* Some more specific error classes have been added to replace the RestClient generic ones.
* Quickly sending a message using the `event << 'text'` syntax now works in every type of message event, not just commands.
* You can now set the bitrate of sent audio data using `bot.voice.encoder.bitrate = 64000` (see [`Encoder#bitrate=`](https://www.rubydoc.info/github/discordrb/discordrb/master/Discordrb/Voice/Encoder#bitrate%3D-instance_method)). Note that sent audio data will always be unaffected by voice channel bitrate settings, those only tell the client at what bitrate it should send.
* A rate limiting feature was added to commands - you can define buckets using the [`bucket`](https://www.rubydoc.info/github/discordrb/discordrb/master/Discordrb%2FCommands%2FRateLimiter%3Abucket) method and use them as a parameter for [`command`](https://www.rubydoc.info/github/discordrb/discordrb/master/Discordrb%2FCommands%2FCommandContainer%3Acommand).
  * A [`SimpleRateLimiter`](https://www.rubydoc.info/github/discordrb/discordrb/master/Discordrb/Commands/SimpleRateLimiter) class was also added if you want rate limiting independent from commands (e. g. for events)
* Connecting to the WebSocket now uses an exponential falloff system so we don't spam Discord with requests anymore.
* Debug timestamps are now accurate to milliseconds.

### Fixed
* The token cacher will now detect whether a cached token has been invalidated due to a password change.
* `break`ing from an event or command will no longer spew `LocalJumpError`s to the console.

## [1.6.6] - 2016-02-13
[1.6.6]: https://github.com/discordrb/discordrb/releases/tag/v1.6.6

[View diff for this release.](https://github.com/discordrb/discordrb/compare/v1.6.5...v1.6.6)

### Fixed
* Fixed a problem that would cause an incompatibility with Ruby 2.1
* Fixed servers sometimes containing duplicate members

## [1.6.5] - 2016-02-12
[1.6.5]: https://github.com/discordrb/discordrb/releases/tag/v1.6.5

[View diff for this release.](https://github.com/discordrb/discordrb/compare/v1.6.4...v1.6.5)

### Changed
* The bot will now request the users that would previously be sent all in one READY packet in multiple chunks. This improves startup time slightly and ensures compatibility with the latest Discord change, but it also means that some users won't be in server members lists until a while after creation (usually a couple seconds at most).

## [1.6.4] - 2016-02-10
[1.6.4]: https://github.com/discordrb/discordrb/releases/tag/v1.6.4

[View diff for this release.](https://github.com/discordrb/discordrb/compare/v1.6.3...v1.6.4)

### Fixed
* Fixed a bug that made the joining of servers using an invite impossible.

## [1.6.3] - 2016-02-08
[1.6.3]: https://github.com/discordrb/discordrb/releases/tag/v1.6.3

[View diff for this release.](https://github.com/discordrb/discordrb/compare/v1.6.2...v1.6.3)

### Fixed
* Fixed a bug that prevented the banning of users over the API

## [1.6.2] - 2016-02-06
[1.6.2]: https://github.com/discordrb/discordrb/releases/tag/v1.6.2

[View diff for this release.](https://github.com/discordrb/discordrb/compare/v1.6.1...v1.6.2)

### Fixed
* RbNaCl is now installed directly instead of the wrapper that also contains libsodium. This has the disadvantage that you will have to install libsodium manually but at least it's not broken on Windows anymore.

## [1.6.1] - 2016-02-04
[1.6.1]: https://github.com/discordrb/discordrb/releases/tag/v1.6.1

[View diff for this release.](https://github.com/discordrb/discordrb/compare/v1.6.0...v1.6.1)

### Changed
* It's now possible to prevent the `READY` packet from being printed in debug mode, run `bot.suppress_ready_debug` once before the `bot.run` to do it.

### Fixed
* Token cache files with invalid JSON syntax will no longer crash the bot at login.

## [1.6.0] - 2016-02-01
[1.6.0]: https://github.com/discordrb/discordrb/releases/tag/v1.6.0

[View diff for this release.](https://github.com/discordrb/discordrb/compare/v1.5.4...v1.6.0)

### Added
* The inline documentation using YARD was greatly improved and is now mostly usable, at least for the data classes and voice classes. It's still not complete enough to be released on GitHub, but you can build it yourself using [YARD](https://yardoc.org/).
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

### Fixed
* Fixed the reader `server.afk_channel_id` not containing a value sometimes.
* An issue was fixed where attempting to create a `Server` object from a stub server that didn't contain any role data would cause an exception.
* The `Invite` `server` property will now be initialized directly from the invite data instead of the channel the invite is to, to prevent it being `nil` when the invite channel was stubbed.
* The `inviter` of an `Invite` will now be `nil` instead of causing an exception when it doesn't exist in the invite data.

## [1.5.4] - 2016-01-16
[1.5.4]: https://github.com/discordrb/discordrb/releases/tag/v1.5.4

[View diff for this release.](https://github.com/discordrb/discordrb/compare/v1.5.3...v1.5.4)

### Changed
* The `opus-ruby` and `levenshtein` dependencies are now optional - if you don't need them, it won't crash immediately (only when you try to use voice / `find` with a threshold > 0, respectively)

### Fixed
* Voice volume can now be properly set when using avconv (#37, thanks @purintai)
* `websocket-client-simple`, which is required for voice, is now specified in the dependencies.

## [1.5.3] - 2016-01-11
[1.5.3]: https://github.com/discordrb/discordrb/releases/tag/v1.5.3

[View diff for this release.](https://github.com/discordrb/discordrb/compare/v1.5.2...v1.5.3)

### Added
* Voice bot length adjustments are now configurable using `bot.voice.adjust_interval` and `bot.voice.adjust_offset` (make sure the latter is less than the first, or no adjustment will be performed at all)
* Length adjustments can now be made more smooth using `bot.voice.adjust_average` (true allows for more smooth adjustments, *may* improve stutteriness but might make it worse as well)

## [1.5.2] - 2016-01-11
[1.5.2]: https://github.com/discordrb/discordrb/releases/tag/v1.5.2

[View diff for this release.](https://github.com/discordrb/discordrb/compare/v1.5.1...v1.5.2)

### Added
* `bot.voice_connect` can now use a channel ID directly.
* A reader `bot.volume` now exists for the corresponding writer.
* The attribute `bot.encoder.use_avconv` was added that makes the bot use avconv instead of ffmpeg (for those on Ubuntu 14.x)
* The PBKDF2 iteration count for token caching was increased to 300,000 for extra security.

### Fixed
* Fix a bug where `play_file` wouldn't properly accept string file paths (#36, thanks @purintai)
* Fix a concurrency issue where `VoiceBot` would try to read from nil

## [1.5.1] - 2016-01-10
[1.5.1]: https://github.com/discordrb/discordrb/releases/tag/v1.5.1

[View diff for this release.](https://github.com/discordrb/discordrb/compare/v1.5.0...v1.5.1)

### Added
* The connection to voice was made more reliable. I haven't experienced any issues with it myself but I got reports where `recv` worked better than `recvmsg`.

## [1.5.0] - 2016-01-10
[1.5.0]: https://github.com/discordrb/discordrb/releases/tag/v1.5.0

[View diff for this release.](https://github.com/discordrb/discordrb/compare/v1.4.8...v1.5.0)

### Added
* Voice support: discordrb can now connect to voice using `bot.voice_connect` and do the following things:
  * Play files and URLs using `VoiceBot.play_file`
  * Play arbitrary streams using `VoiceBot.play_io`
  * Set the volume of future playbacks using `VoiceBot.volume=`
  * Pause and resume playback (`VoiceBot.pause` and `VoiceBot.continue`)
* Authentication tokens are now cached and no login request will be made if a cached token is found. This is mostly to reduce strain on Discord's servers.

### Fixed
* Some latent ID casting errors were fixed - those would probably never have been noticed anyway, but they're fixed now.
* `Bot.parse_mention` now works, it didn't work at all previously

## [1.4.8] - 2016-01-06
[1.4.8]: https://github.com/discordrb/discordrb/releases/tag/v1.4.8

[View diff for this release.](https://github.com/discordrb/discordrb/compare/v1.4.7...v1.4.8)

### Added
* The `User` class now has the methods `add_role` and `remove_role` which add a role to a user and remove it, respectively.
* All data classes now have a useful `==` implementation.
* **The `Game` class and all references to it were removed**. Games are now only identified by their name.

### Fixed
* When a role is deleted, the ID is now obtained correctly. (#30)

## [1.4.7] - 2016-01-03
[1.4.7]: https://github.com/discordrb/discordrb/releases/tag/v1.4.7

[View diff for this release.](https://github.com/discordrb/discordrb/compare/v1.4.6...v1.4.7)

### Added
* Presence event handling is now divided into two separate events; `PresenceEvent` to handle online/offline/idle statuses and `PlayingEvent` to handle users playing games.
* The `user` property of `MessageEvent` is now automatically resolved to the cached user, so you can modify roles instantly without having to resolve it yourself.
* `Message` now has a useful `to_s` method that just returns the content.

### Fixed
* The `TypingEvent` `user` property is now initialized correctly (#29, thanks @purintai)

## [1.4.6] - 2015-12-25
[1.4.6]: https://github.com/discordrb/discordrb/releases/tag/v1.4.6

[View diff for this release.](https://github.com/discordrb/discordrb/compare/v1.4.4...v1.4.6)

### Fixed
* The `user` and `server` properties of `PresenceEvent` are now initialized correctly.

## 1.4.5
<!-- This was never tagged in the git repo -->
### Changed
* The `Bot.game` property can now be set to an arbitrary string.
* Discord mentions are handled in the old way again, after Discord reverted an API change.

## [1.4.4] - 2015-12-18
[1.4.4]: https://github.com/discordrb/discordrb/releases/tag/v1.4.4

[View diff for this release.](https://github.com/discordrb/discordrb/compare/v1.4.3...v1.4.4)

### Added
* Add `Server.leave_server` as an alias for `delete_server`
* Use the new Discord mention format (mentions array). **Reverted in 1.4.5**
* Discord rate limited API calls are now handled correctly - discordrb will try again after the specified time.
* Debug logging is now handled by a separate `Logger` class

### Fixed
* Message timestamps are now parsed correctly.
* The quickadders for awaits (`User.await`, `Channel.await` etc.) now add the correct awaits.

## [1.4.3] - 2015-12-11
[1.4.3]: https://github.com/discordrb/discordrb/releases/tag/v1.4.3

[View diff for this release.](https://github.com/discordrb/discordrb/compare/v1.4.2...v1.4.3)

### Added
* Added a method `Bot.find_user` analogous to `Bot.find`.

### Fixed
* Remove a leftover debug line (#23, thanks @VxJasonxV)

## [1.4.2] - 2015-12-10
[1.4.2]: https://github.com/discordrb/discordrb/releases/tag/v1.4.2

[View diff for this release.](https://github.com/discordrb/discordrb/compare/v1.4.1...v1.4.2)

### Changed
* discordrb will now send a user agent in the format requested by the Discord devs.

## [1.4.1] - 2015-12-07
[1.4.1]: https://github.com/discordrb/discordrb/releases/tag/v1.4.1

[View diff for this release.](https://github.com/discordrb/discordrb/compare/v1.4.0...v1.4.1)

### Fixed
* Empty messages will now never be sent
* The command-not-found message in `CommandBot` can now be disabled properly

## [1.4.0] - 2015-12-04
[1.4.0]: https://github.com/discordrb/discordrb/releases/tag/v1.4.0

[View diff for this release.](https://github.com/discordrb/discordrb/compare/v1.3.12...v1.4.0)

### Added
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

### Fixed
* Fixed a bug where command handling would crash if the command didn't exist.

## [1.3.12] - 2015-11-30
[1.3.12]: https://github.com/discordrb/discordrb/releases/tag/v1.3.12

[View diff for this release.](https://github.com/discordrb/discordrb/compare/v1.3.11...v1.3.12)

### Added
* Add an attribute `Bot.should_parse_self` (false by default) that prevents the bot from raising an event if it receives a message from itself.
* `User.bot?` and `Message.from_bot?` were implemented to check whether the user is the bot or the message was sent by it.
* Add an event for private messages specifically (`Bot.pm` and `PrivateMessageEvent`)

### Fixed
* Fix the `MessageEvent` attribute that checks whether the message is from the bot not working at all.

## [1.3.11] - 2015-11-29
[1.3.11]: https://github.com/discordrb/discordrb/releases/tag/v1.3.11

[View diff for this release.](https://github.com/discordrb/discordrb/compare/v1.3.10...v1.3.11)

### Added
* Add a user selector (`:bot`) that is usable in the `from:` `MessageEvent` attribute to check whether the message was sent by a bot.

### Fixed
* `Channel.private?` now checks for the server being nil instead of the `is_private` attribute provided by Discord as the latter is unreliable. (wtf)

## [1.3.10] - 2015-11-28
[1.3.10]: https://github.com/discordrb/discordrb/releases/tag/v1.3.10

[View diff for this release.](https://github.com/discordrb/discordrb/compare/v1.3.9...v1.3.10)

### Added
* Add a method `Channel.private?` to check for a PM channel
* Add a `MessageEvent` attribute (`:private`) to check whether a message was sent in a PM channel
* Add various aliases to `MessageEvent` attributes
* Allow regexes to check for strings in `MessageEvent` attributes

### Fixed
* The `matches_all` method would break in certain edge cases. This didn't really affect discordrb and I don't think anyone else uses that method (it's pretty useless otherwise). This has been fixed

## [1.3.9] - 2015-11-27
[1.3.9]: https://github.com/discordrb/discordrb/releases/tag/v1.3.9

[View diff for this release.](https://github.com/discordrb/discordrb/compare/v1.3.8...v1.3.9)

### Added
* Add awaits, a powerful way to add temporary event handlers.
* Add a `Bot.find` method to fuzzy-search for channels.
* Add methods to kick, ban and unban users.

### Fixed
* Permission overrides now work correctly for private channels (i. e. they don't exist at all)
* Users joining and leaving servers are now handled correctly.

## [1.3.8] - 2015-11-12
[1.3.8]: https://github.com/discordrb/discordrb/releases/tag/v1.3.8

[View diff for this release.](https://github.com/discordrb/discordrb/compare/v1.3.7...v1.3.8)

### Added
* Added `Bot.users` and `Bot.servers` readers to get the list of users and servers.

### Fixed
* POST requests to API calls that don't need a payload will now send a `nil` payload instead. This fixes the bot being unable to join any servers and various other latent problems. (#21, thanks @davidkus)

## [1.3.7] - 2015-11-07
[1.3.7]: https://github.com/discordrb/discordrb/releases/tag/v1.3.7

[View diff for this release.](https://github.com/discordrb/discordrb/compare/v1.3.6...v1.3.7)

### Fixed
* Fix the command bot being included wrong, which caused crashes upon startup.

## [1.3.6] - 2015-11-07
[1.3.6]: https://github.com/discordrb/discordrb/releases/tag/v1.3.6

[View diff for this release.](https://github.com/discordrb/discordrb/compare/v1.3.5...v1.3.6)

### Added
* The bot can now be stopped from the script using the new method `Bot.stop`.

### Fixed
* Fix some wrong file requires which caused crashes sometimes.

## [1.3.5] - 2015-11-07
[1.3.5]: https://github.com/discordrb/discordrb/releases/tag/v1.3.5

[View diff for this release.](https://github.com/discordrb/discordrb/compare/v1.3.4...v1.3.5)

### Added
* The bot can now be run asynchronously using `Bot.run(:async)` to do further initialization after the bot was started.
