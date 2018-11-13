# frozen_string_literal: true

require 'rubygems'
require 'rubygems/command'
require 'rubygems/dependency_installer'

Gem::Command.build_args = ARGV

installer = Gem::DependencyInstaller.new
begin
  if RUBY_VERSION >= '2.5.0' && Gem.win_platform?
    puts 'Installing on Ruby >= 2.5.0 on a Windows OS, so rest-client ~> 2.1.0.rc1 will be used'
    installer.install 'rest-client', '~> 2.1.0.rc1'
  else
    installer.install 'rest-client', '~> 2.0'
  end
rescue StandardError
  exit(1)
end

# Create dummy rakefile to indicate success
path = File.join(File.dirname(__FILE__), 'Rakefile')
File.open(path, 'w') do |file|
  file.write("task :default\n")
end
