# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'discordrb/version'

Gem::Specification.new do |spec|
  spec.name          = 'discordrb'
  spec.version       = Discordrb::VERSION
  spec.authors       = ['meew0']
  spec.email         = ['']

  spec.summary       = 'Discord API for Ruby'
  spec.description   = 'A Ruby implementation of the Discord (https://discordapp.com) API.'
  spec.homepage      = 'https://github.com/meew0/discordrb'
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'faye-websocket'
  spec.add_dependency 'rest-client'
  spec.add_dependency 'activesupport'

  spec.required_ruby_version = '>= 2.1.0'

  spec.add_development_dependency 'bundler', '~> 1.10'
  spec.add_development_dependency 'rake', '~> 10.0'
end
