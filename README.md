[![Gem](https://img.shields.io/gem/v/discordrb.svg)](https://rubygems.org/gems/discordrb)
[![Gem](https://img.shields.io/gem/dt/discordrb.svg)](https://rubygems.org/gems/discordrb)
[![CircleCI](https://circleci.com/gh/shardlab/discordrb.svg?style=svg)](https://circleci.com/gh/shardlab/discordrb)
[![Inline docs](http://inch-ci.org/github/shardlab/discordrb.svg?branch=main)](http://inch-ci.org/github/shardlab/discordrb)
[![Join Discord](https://img.shields.io/badge/discord-join-7289DA.svg)](https://discord.gg/cyK3Hjm)
# discordrb

An implementation of the [Discord](https://discord.com/) API using Ruby.

## Quick links to sections

* [Introduction](https://github.com/shardlab/discordrb#introduction)
* [Dependencies](https://github.com/shardlab/discordrb#dependencies)
* [Installation](https://github.com/shardlab/discordrb#installation)
* [Usage](https://github.com/shardlab/discordrb#usage)
* [Webhooks Client](https://github.com/shardlab/discordrb#webhooks-client)
* [Support](https://github.com/shardlab/discordrb#support)
* [Development](https://github.com/shardlab/discordrb#development), [Contributing](https://github.com/shardlab/discordrb#contributing)
* [License](https://github.com/shardlab/discordrb#license)

See also: [Documentation](https://www.rubydoc.info/gems/discordrb), [Tutorials](https://github.com/shardlab/discordrb/wiki)

## Introduction

`discordrb` aims to meet the following design goals:

1. Full coverage of the public bot API.
2. Expressive, high level abstractions for rapid development of common applications.
3. Friendly to Ruby beginners and beginners of open source contribution.

If you enjoy using the library, consider getting involved with the community to help us improve and meet these goals!

**You should consider using `discordrb` if:**

- You need a bot - and fast - for small or medium sized communities, and don't want to be bogged down with "low level" details. Getting started takes minutes, and utilities like a command parser and tools for modularization make it simple to quickly add or change your bots functionality.
- You like or want to learn Ruby, or want to contribute to a Ruby project. A lot of our users are new to Ruby, and eventually make their first open source contributions with us. We have an active Discord channel with experienced members who will happily help you get involved, either as a user or contributor.
- You want to experiment with Discord's API or prototype concepts for Discord bots without too much commitment.

**You should consider other libraries if:**

- You need to scale to large volumes of servers (>2,500) with lots of members. It's still possible, but it can be difficult to scale Ruby processes, and it requires more in depth knowledge to do so well. Especially if you already have a bot that is on a large amount of servers, porting to Ruby is unlikely to improve your performance in most cases.
- You want full control over the library that you're using. While we expose some "lower level" interfaces, they are unstable, and only exist to serve the more powerful abstractions in the library.

## Dependencies

* Ruby >= 2.5 supported
* An installed build system for native extensions (on Windows, make sure you download the "Ruby+Devkit" version of [RubyInstaller](https://rubyinstaller.org/downloads/))

### Voice dependencies

This section only applies to you if you want to use voice functionality.
* [libsodium](https://github.com/shardlab/discordrb/wiki/Installing-libsodium)
* A compiled libopus distribution for your system, anywhere the script can find it. See [here](https://github.com/shardlab/discordrb/wiki/Installing-libopus) for installation instructions.
* [FFmpeg](https://www.ffmpeg.org/download.html) installed and in your PATH

## Installation

### With Bundler

Using [Bundler](https://bundler.io/#getting-started), you can add discordrb to your Gemfile:

    gem 'discordrb'

And then install via `bundle install`.

Run the [ping example](https://github.com/shardlab/discordrb/blob/master/examples/ping.rb) to verify that the installation works (make sure to replace the token and client ID in there with your bots'!):

To run the bot while using bundler:

    bundle exec ruby ping.rb

### With Gem

Alternatively, while Bundler is the recommended option, you can also install discordrb without it.

#### Linux / macOS

    gem install discordrb

#### Windows

> **Make sure you have the DevKit installed! See the [Dependencies](https://github.com/shardlab/discordrb#dependencies) section)**

    gem install discordrb --platform=ruby

To run the bot:

    ruby ping.rb

### Installation Troubleshooting

See https://github.com/shardlab/discordrb/wiki/FAQ#installation for a list of common problems and solutions when installing `discordrb`.

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

See [additional examples here](https://github.com/shardlab/discordrb/tree/master/examples).

You can find examples of projects that use discordrb by [searching for the discordrb topic on GitHub](https://github.com/topics/discordrb).

If you've made an open source project on GitHub that uses discordrb, consider adding the `discordrb` topic to your repo!

## Webhooks Client

Also included is a webhooks client, which can be used as a separate gem `discordrb-webhooks`. This special client can be used to form requests to Discord webhook URLs in a high-level manner.

- [`discordrb-webhooks` documentation](https://www.rubydoc.info/gems/discordrb-webhooks)
- [More information about webhooks](https://support.discord.com/hc/en-us/articles/228383668-Intro-to-Webhooks)
- [Embed visualizer tool](https://leovoel.github.io/embed-visualizer/) - Includes a discordrb code generator for forming embeds

### Usage

```ruby
require 'discordrb/webhooks'

WEBHOOK_URL = 'https://discord.com/api/webhooks/424070213278105610/yByxDncRvHi02mhKQheviQI2erKkfRRwFcEp0MMBfib1ds6ZHN13xhPZNS2-fJo_ApSw'.freeze

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

If you need help or have a question, you can:

1. Join our [Discord channel](https://discord.gg/cyK3Hjm). This is the fastest means of getting support.
2. [Open an issue](https://github.com/shardlab/discordrb/issues). Be sure to read the issue template, and provide as much detail as you can.

## Contributing

Thank you for your interest in contributing!
Bug reports and pull requests are welcome on GitHub at https://github.com/shardlab/discordrb.

In general, we recommend starting by discussing what you would like to contribute in the [Discord channel](https://discord.gg/cyK3Hjm).
There are usually a handful of people working on things for the library, and what you're looking for may already be on the way.

Additionally, there is a chance what you are looking for might already exist, or we decided not to pursue it for some reason.
Be sure to use the search feature on our documentation, GitHub, and Discord to see if this might be the case.

## Development setup

**This section is for developing discordrb itself! If you just want to make a bot, see the [Installation](https://github.com/shardlab/discordrb#installation) section.**

After checking out the repo, run `bin/setup` to install dependencies. You can then run tests via `bundle exec rspec spec`. Make sure to run rubocop also: `bundle exec rubocop`. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
