# Changelog
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
* The `TypingEvent` `user` property is now initialized correctly (#29, thanks @purintal)

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
