# Changelog
## 1.4.7
* Presence event handling is now divided into two separate events; `PresenceEvent` to handle online/offline/idle statuses and `PlayingEvent` to handle users playing games.
* The `user` property of `MessageEvent` is now automatically resolved to the cached user, so you can modify roles instantly without having to resolve it yourself.
* `Message` now has a useful `to_s` method that just returns the content.
### Bugfixes
* The `TypingEvent` `user` property is now initialized correctly.
## 1.4.6
*Bugfix-only release.*
### Bugfixes
* The `user` and `server` properties of `PresenceEvent` are now initialized correctly.
## 1.4.5
* The `Bot.game` property can now be set to an arbitrary string.
* Discord mentions are handled in the old way again, after Discord reverted an API change.
