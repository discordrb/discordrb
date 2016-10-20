require 'bundler/gem_helper'

namespace :main do
  Bundler::GemHelper.install_tasks(name: 'discordrb')
end

namespace :webhooks do
  Bundler::GemHelper.install_tasks(name: 'discordrb-webhooks')
end

task build: [:'main:build', :'webhooks:build']
task release: [:'main:release', :'webhooks:release']

# Make "build" the default task
task default: :build
