# discordrb

An implementation of the [Discord](https://discordapp.com/) API using Ruby.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'discordrb'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install discordrb

## Usage

You can make a simple bot like this:

    require 'discordrb'

    bot = Discordrb::Bot.new "email@example.com", "hunter2"

    bot.message(with_text: "Ping!") do |event|
      event.respond "Pong!"
    end

    bot.run

This bot responds to every "Ping!" with a "Pong!".

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake false` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/meew0/discordrb.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
