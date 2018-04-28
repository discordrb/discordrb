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

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features|examples|lib/discordrb/webhooks)/}) }
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.metadata = {
    'changelog_uri' => 'https://github.com/meew0/discordrb/blob/master/CHANGELOG.md'
  }
  spec.require_paths = ['lib']

  spec.add_dependency 'ffi', '>= 1.9.24'
  spec.add_dependency 'opus-ruby'
  spec.add_dependency 'rbnacl', '~> 3.4.0' # 24: update
  spec.add_dependency 'rest-client', '>= 2.1.0.rc1'
  spec.add_dependency 'websocket-client-simple', '>= 0.3.0'

  spec.add_dependency 'discordrb-webhooks', '~> 3.3.0'

  spec.required_ruby_version = '>= 2.2.4'

  spec.add_development_dependency 'bundler', '~> 1.10'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'redcarpet', '~> 3.4.0' # YARD markdown formatting
  spec.add_development_dependency 'rspec', '~> 3.4.0'
  spec.add_development_dependency 'rspec-prof', '~> 0.0.7'
  spec.add_development_dependency 'rubocop', '0.55.0'
  spec.add_development_dependency 'simplecov', '~> 0.16.0'
  spec.add_development_dependency 'yard', '~> 0.9.9'
end
