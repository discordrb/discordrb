# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'discordrb/webhooks/version'

Gem::Specification.new do |spec|
  spec.name          = 'discordrb-webhooks'
  spec.version       = Discordrb::Webhooks::VERSION
  spec.authors       = %w[meew0 swarley]
  spec.email         = ['']

  spec.summary       = 'Webhook client for discordrb'
  spec.description   = "A client for Discord's webhooks to fit alongside [discordrb](https://rubygems.org/gems/discordrb)."
  spec.homepage      = 'https://github.com/shardlab/discordrb'
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z lib/discordrb/webhooks/`.split("\x0") + ['lib/discordrb/webhooks.rb']
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'rest-client', '>= 2.0.0'

  spec.required_ruby_version = '>= 2.5'
end
