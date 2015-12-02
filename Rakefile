require 'bundler/gem_tasks'

# Make "build" the default task
task default: :build

# Make build depend on update_lists
task build: :update_lists

task :update_lists do
  ruby 'util/update_lists.rb'
end
