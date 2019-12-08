[![Gem](https://img.shields.io/gem/v/discordrb.svg)](https://rubygems.org/gems/discordrb)
[![Gem](https://img.shields.io/gem/dt/discordrb.svg)](https://rubygems.org/gems/discordrb)
[![Build Status](https://travis-ci.org/discordrb/discordrb.svg?branch=master)](https://travis-ci.org/discordrb/discordrb)
[![Inline docs](https://inch-ci.org/github/discordrb/discordrb.svg?branch=master&style=shields)](https://inch-ci.org/github/discordrb/discordrb)
[![Code Climate](https://codeclimate.com/github/discordrb/discordrb/badges/gpa.svg)](https://codeclimate.com/github/discordrb/discordrb)
[![Test Coverage](https://codeclimate.com/github/discordrb/discordrb/badges/coverage.svg)](https://codeclimate.com/github/discordrb/discordrb/coverage)
[![Join Discord](https://img.shields.io/badge/discord-join-7289DA.svg)](https://discord.gg/cyK3Hjm)
# discordrb

An implementation of the [Discord](https://discordapp.com/) API using Ruby.

## Quick links to sections

* [Introcution](https://github.com/discordrb/discordrb#introduction)
* [Dependencies](https://github.com/discordrb/discordrb#dependencies)
* [Installation](https://github.com/discordrb/discordrb#installation)
* [Usage](https://github.com/discordrb/discordrb#usage)
* [Webhooks Client](https://github.com/discordrb/discordrb#webhooks-client)
* [Support](https://github.com/discordrb/discordrb#support)
* [Development](https://github.com/discordrb/discordrb#development), [Contributing](https://github.com/discordrb/discordrb#contributing)
* [License](https://github.com/discordrb/discordrb#license)

See also: [Documentation](https://www.rubydoc.info/gems/discordrb), [Tutorials](https://github.com/discordrb/discordrb/wiki)

## Introduction

`discordrb` aims to meet the following design goals:

1. Full coverage of the public bot API.
2. Expressive, high level abstractions for rapid development of common applications.
3. Friendly to Ruby beginners, as well as beginners of open source contribution.

If you enjoy using the library, consider getting involved with the community to help us improve and meet these goals!

**You should consider using `discordrb` if:**

- You need a bot - and fast - for small or medium sized communities, and don't want to be bogged down with "low level" details. Getting started takes minutes, and with utilities like a command parser and tools for modularization make it simple to quickly add or change your bots functionality.
- You like or want to learn Ruby, or want to contribute to a Ruby project. A lot of our users are newcomers to Ruby, who eventually make their first open source contributions with us. We have an active Discord channel with experienced members who will happily help  you get involved, either as a user or contributor.
- You want to experiment with Discord's API or prototype concepts for Discord bots without too much commitment.

**You should consider other libraries if:**

- You need to scale to large volumes of servers (>2,500) with lots of members. It's still possible, but it can be difficult to scale Ruby processes, and it requires more in depth knowledge to do so well. Especially if you already have a bot that is on a large amount of servers, porting to Ruby is unlikely to improve your performance in most cases.
- You want full control over the library that you're using. While we expose some "lower level" interfaces, they are unstable, and only exist to serve the more powerful abstractions in the library.

## Dependencies

* Ruby >= 2.4 supported
* An installed build system for native extensions (on Windows, make sure you download the "Ruby+Devkit" version of [RubyInstaller](https://rubyinstaller.org/downloads/))

> **Note:** RubyInstaller for Ruby versions 2.4+ will install the DevKit as the last step of the installation.

### Voice dependencies

This section only applies to you if you want to use voice functionality.
* [libsodium](https://github.com/discordrb/discordrb/wiki/Installing-libsodium)
* A compiled libopus distribution for your system, anywhere the script can find it. See [here](https://github.com/discordrb/discordrb/wiki/Installing-libopus) for installation instructions.
* [FFmpeg](https://www.ffmpeg.org/download.html) installed and in your PATH

In addition to this, if you're on Windows and want to use voice functionality, your installed Ruby version **needs to be 32 bit**, as otherwise Opus won't work.

## Installation

### With Bundler

Using [Bundler](https://bundler.io/#getting-started), you can add discordrb to your Gemfile:

    gem 'discordrb'

And then install via `bundle install`.

Run the [ping example](https://github.com/discordrb/discordrb/blob/master/examples/ping.rb) to verify that the installation works (make sure to replace the token and client ID in there with your bots'!):

To run the bot while using bundler:

    bundle exec ruby ping.rb

### With Gem

Alternatively, while Bundler is the recommended option, you can also install discordrb without it.

#### Linux / macOS

    gem install discordrb

#### Windows

> **Make sure you have the DevKit installed! See the [Dependencies](https://github.com/discordrb/discordrb#dependencies) section)**

    gem install discordrb --platform=ruby

To run the bot:

    ruby ping.rb

### Installation Troubleshooting

See https://github.com/discordrb/discordrb/wiki/FAQ#installation for a list of common problems and solutions when installing `discordrb`.

## Usage

You can make a simple bot like this:

```ruby
require 'discordrb'

bot = Discordrb::Bot.new token: '<token here>'

bot.message(with_text: 'Ping!') do |event|
  event.respond 'Pong!'
end

bot.run
```

This bot responds to every "Ping!" with a "Pong!".

See [additional examples here](https://github.com/discordrb/discordrb/tree/master/examples).

You can find examples of projects that use discordrb by [searching for the discordrb topic on GitHub](https://github.com/topics/discordrb).

If you've made an open source project on GitHub that uses discordrb, consider adding the `discordrb` topic to your repo!

## Webhooks Client

Also included is a webhooks client, which can be used as a separate gem `discordrb-webhooks`. This special client can be used to form requests to Discord webhook URLs in a high-level manner.

- [`discordrb-webhooks` documentation](https://www.rubydoc.info/gems/discordrb-webhooks)
- [More information about webhooks](https://support.discordapp.com/hc/en-us/articles/228383668-Intro-to-Webhooks)
- [Embed visualizer tool](https://leovoel.github.io/embed-visualizer/) - Includes a discordrb code generator for forming embeds

### Usage

```ruby
require 'discordrb/webhooks'

WEBHOOK_URL = 'https://discordapp.com/api/webhooks/424070213278105610/yByxDncRvHi02mhKQheviQI2erKkfRRwFcEp0MMBfib1ds6ZHN13xhPZNS2-fJo_ApSw'.freeze

client = Discordrb::Webhooks::Client.new(url: WEBHOOK_URL)
client.execute do |builder|
  builder.content = 'Hello world!'
  builder.add_embed do |embed|
    embed.title = 'Embed title'
    embed.description = 'Embed description'
    embed.timestamp = Time.now
  end
end
```

**Note:** The `discordrb` gem relies on `discordrb-webhooks`. If you already have `discordrb` installed, `require 'discordrb/webhooks'` will include all of the `Webhooks` features as well.

## Support

You can find me (@meew0, ID 66237334693085184) on the unofficial Discord API server - if you have a question, just ask there, I or somebody else will probably answer you: https://discord.gg/3Trm6FW

## Development

**This section is for developing discordrb itself! If you just want to make a bot, see the [Installation](https://github.com/discordrb/discordrb#installation) section.**

After checking out the repo, run `bin/setup` to install dependencies. You can then run tests via `bundle exec rspec spec`. Make sure to run rubocop also: `bundle exec rubocop`. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/discordrb/discordrb.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
