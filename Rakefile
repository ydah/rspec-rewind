# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new(:spec)

desc 'Validate RBS signatures'
task :rbs do
  sh 'bundle exec rbs validate'
end

task default: %i[spec rbs]
