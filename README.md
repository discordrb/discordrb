[![Build Status](https://travis-ci.org/meew0/discordrb.svg?branch=master)](https://travis-ci.org/meew0/discordrb)

# discordrb

An implementation of the [Discord](https://discordapp.com/) API using Ruby.

## Quick links to sections

* [Installation](https://github.com/meew0/discordrb#installation)
* [Usage](https://github.com/meew0/discordrb#usage)
* [Support](https://github.com/meew0/discordrb#support)
* [Development](https://github.com/meew0/discordrb#development), [Contributing](https://github.com/meew0/discordrb#contributing)
* [License](https://github.com/meew0/discordrb#license)

See also: [Documentation](https://discord.gg/0SBTUU1wZTWfFQL2), [Tutorials](https://github.com/meew0/discordrb/wiki)

## Installation

### Linux

On Linux, it should be as simple as running:

    gem install discordrb

### Windows

On Windows, to install discordrb, run this in a shell:

    gem install discordrb

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

**If you get an error like this when running the example**:

    terminate called after throwing an instance of 'std::runtime_error'
      what():  Encryption not available on this event-machine

You're missing the OpenSSL libraries that EventMachine, a dependency of discordrb, needs to be built with to use encrypted connections (which Discord requires). Download the OpenSSL libraries from [here](https://slproweb.com/download/Win32OpenSSL-1_0_2f.exe), install them to their default location and reinstall EventMachine using these libraries:

    gem uninstall eventmachine
    gem install eventmachine -- --with-ssl-dir=C:/OpenSSL-Win32

**If you're having trouble getting voice playback to work**:

Look here: https://github.com/meew0/discordrb/wiki/Voice-sending#troubleshooting

## Usage

You can make a simple bot like this:

```ruby
require 'discordrb'

bot = Discordrb::Bot.new "email@example.com", "hunter2"

bot.message(with_text: "Ping!") do |event|
  event.respond "Pong!"
end

bot.run
```

This bot responds to every "Ping!" with a "Pong!".

## Support

You can find me (@meew0, ID 66237334693085184) on the unofficial Discord API server - if you have a question, just ask there, I or somebody else will probably answer you: https://discord.gg/0SBTUU1wZTWfFQL2

## Development

After checking out the repo, run `bin/setup` to install dependencies. You can then run tests via `bundle exec rspec spec`. Make sure to run rubocop also: `bundle exec rubocop`. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/meew0/discordrb.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
