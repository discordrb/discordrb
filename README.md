# discordrb

An implementation of the [Discord](https://discordapp.com/) API using Ruby.

## Installation

### Linux

On Linux, it should be as simple as running:

    $ gem install discordrb

### Windows

On Windows, to install discordrb, run this in a shell:

    $ gem install discordrb

Run the [ping example](https://github.com/meew0/discordrb/blob/master/examples/ping.rb) to verify that the installation works:

    $ ruby ping.rb

#### Troubleshooting

**If you get an error like this when installing the gem**:

    ERROR:  Error installing discordrb:
            The 'websocket-driver' native gem requires installed build tools.

You're missing the development kit required to build native extensions. Follow [these instructions](https://github.com/oneclick/rubyinstaller/wiki/Development-Kit#installation-instructions) and reinstall discordrb:

    $ gem uninstall discordrb
    $ gem install discordrb

**If you get an error like this when running the example**:

    terminate called after throwing an instance of 'std::runtime_error'
      what():  Encryption not available on this event-machine

You're missing the OpenSSL libraries that EventMachine, a dependency of discordrb, needs to be built with to use encrypted connections (which Discord requires). Download the OpenSSL libraries from [here](http://slproweb.com/download/Win32OpenSSL-1_0_2d.exe), install them to their default location and reinstall EventMachine using these libraries:

    $ gem uninstall eventmachine
    $ gem install eventmachine -- --with-ssl-dir=C:/OpenSSL-Win32

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

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake false` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/meew0/discordrb.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
