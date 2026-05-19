# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rbconfig'
require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new(:spec)

desc 'Syntax check Ruby source and specs'
task :syntax do
  files = FileList['lib/**/*.rb', 'spec/**/*.rb', '*.gemspec', 'Rakefile']
  files.each { |file| sh RbConfig.ruby, '-c', file }
end

desc 'Validate RBS signatures'
task :rbs do
  sh 'bundle exec rbs validate'
end

desc 'Run RuboCop style lint'
task :rubocop do
  sh 'bundle exec rubocop'
end

desc 'Run focused mutation tests for retry policy code when mutant is installed'
task :mutation do
  unless system('bundle exec mutant --version', out: File::NULL, err: File::NULL)
    abort 'mutant is not installed; add it to the development bundle to run mutation tests'
  end

  sh 'bundle exec mutant run --require ./lib/rspec/rewind/core ' \
     'RSpec::Rewind::RetryDecision RSpec::Rewind::RetryPolicy ' \
     'RSpec::Rewind::RetryGate RSpec::Rewind::RetryCountResolver'
end

task default: %i[spec rbs]
