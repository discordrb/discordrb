# frozen_string_literal: true

require 'bundler/gem_helper'
require 'rake/extensiontask'

Rake::ExtensionTask.new 'discordrb/parse_mentions' do |ext|
  ext.lib_dir = 'lib/'
end

namespace :main do
  Bundler::GemHelper.install_tasks(name: 'discordrb')
end

namespace :webhooks do
  Bundler::GemHelper.install_tasks(name: 'discordrb-webhooks')
end

task build: %i[main:build webhooks:build]
task release: %i[main:release webhooks:release]

# Make "build" the default task
task default: :build
