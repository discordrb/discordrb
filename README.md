[![Gem](https://img.shields.io/gem/v/discordrb.svg)](https://rubygems.org/gems/discordrb)
[![Gem](https://img.shields.io/gem/dt/discordrb.svg)](https://rubygems.org/gems/discordrb)
[![Build Status](https://travis-ci.org/meew0/discordrb.svg?branch=master)](https://travis-ci.org/meew0/discordrb)
[![Inline docs](http://inch-ci.org/github/meew0/discordrb.svg?branch=master&style=shields)](http://inch-ci.org/github/meew0/discordrb)
[![Code Climate](https://codeclimate.com/github/meew0/discordrb/badges/gpa.svg)](https://codeclimate.com/github/meew0/discordrb)
[![Test Coverage](https://codeclimate.com/github/meew0/discordrb/badges/coverage.svg)](https://codeclimate.com/github/meew0/discordrb/coverage)
[![Join Discord](https://img.shields.io/badge/discord-join-7289DA.svg)](https://discord.gg/0SBTUU1wZTWfFQL2)
# discordrb

An implementation of the [Discord](https://discordapp.com/) API using Ruby.

## Quick links to sections

* [Dependencies](https://github.com/meew0/discordrb#dependencies)
* [Installation](https://github.com/meew0/discordrb#installation)
* [Usage](https://github.com/meew0/discordrb#usage)
* [Support](https://github.com/meew0/discordrb#support)
* [Development](https://github.com/meew0/discordrb#development), [Contributing](https://github.com/meew0/discordrb#contributing)
* [License](https://github.com/meew0/discordrb#license)

See also: [Documentation](http://www.rubydoc.info/gems/discordrb), [Tutorials](https://github.com/meew0/discordrb/wiki)

## Dependencies

* Ruby 2.1+
* An installed build system for native extensions (on Windows, try the [DevKit](http://rubyinstaller.org/downloads/); installation instructions [here](https://github.com/oneclick/rubyinstaller/wiki/Development-Kit#quick-start) - you only need to do the quick start)

### Voice dependencies

This section only applies to you if you want to use voice functionality.
* [libsodium](https://github.com/meew0/discordrb/wiki/Installing-libsodium)
* A compiled libopus distribution for your system, anywhere the script can find it. See [here](https://github.com/meew0/discordrb/wiki/Installing-libopus) for installation instructions.
* [FFmpeg](https://www.ffmpeg.org/download.html) installed and in your PATH

In addition to this, if you're on Windows and want to use voice functionality, your installed Ruby version **needs to be 32 bit**, as otherwise Opus won't work.

## Installation

### Linux

On Linux, it should be as simple as running:

    gem install discordrb

### Windows

On Windows, to install discordrb, run this in a shell **(make sure you have the DevKit installed! See the [Dependencies](https://github.com/meew0/discordrb#dependencies) section)**:

    gem install discordrb --platform=ruby

Run the [ping example](https://github.com/meew0/discordrb/blob/master/examples/ping.rb) to verify that the installation works (make sure to replace the username and password in there with your own or your bots'!):

    ruby ping.rb

#### Troubleshooting

**If you get an error like this when installing the gem**:

    ERROR:  Error installing discordrb:
            The 'websocket-driver' native gem requires installed build tools.

You're missing the development kit required to build native extensions. Download the development kit [here](http://rubyinstaller.org/downloads/) (scroll down to "Development Kit", then choose the one for Ruby 2.0 and your system architecture) and extract it somewhere. Open a command prompt in that folder and run:

    ruby dk.rb init
    ruby dk.rb install

Then reinstall discordrb:

    gem uninstall discordrb
    gem install discordrb

**If Ruby complains about `ffi_c` not being able to be found:**

For example

    C:/Ruby23-x64/lib/ruby/2.3.0/rubygems/core_ext/kernel_require.rb:55:in `require': cannot load such file -- ffi_c (LoadError)

Your ffi setup is screwed up, first run `gem uninstall ffi` (uninstall all versions if it asks you, say yes to any unmet dependencies), then run `gem install ffi --platform=ruby` to fix it. If it says something about build tools, follow the steps in the first troubleshooting section.

**If you're having trouble getting voice playback to work**:

Look here: https://github.com/meew0/discordrb/wiki/Voice-sending#troubleshooting

## Usage

You can make a simple bot like this:

```ruby
require 'discordrb'

bot = Discordrb::Bot.new token: '<token here>', client_id: 168123456789123456

bot.message(with_text: 'Ping!') do |event|
  event.respond 'Pong!'
end

bot.run
```

This bot responds to every "Ping!" with a "Pong!".

## Support

You can find me (@meew0, ID 66237334693085184) on the unofficial Discord API server - if you have a question, just ask there, I or somebody else will probably answer you: https://discord.gg/0SBTUU1wZTWfFQL2

## Development

**This section is for developing discordrb itself! If you just want to make a bot, see the [Installation](https://github.com/meew0/discordrb#installation) section.**

After checking out the repo, run `bin/setup` to install dependencies. You can then run tests via `bundle exec rspec spec`. Make sure to run rubocop also: `bundle exec rubocop`. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/meew0/discordrb.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
