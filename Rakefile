# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rbconfig'
require 'rspec/core/rake_task'
require 'tmpdir'
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

desc 'Build, install, and require the packaged gem'
task install_smoke: :build do
  gem_path = FileList['pkg/rspec-rewind-*.gem'].max_by { |path| File.mtime(path) }
  abort 'built gem was not found under pkg/' unless gem_path

  Dir.mktmpdir('rspec-rewind-gem-home') do |gem_home|
    env = {
      'BUNDLE_GEMFILE' => nil,
      'GEM_HOME' => gem_home,
      'GEM_PATH' => ([gem_home] + Gem.path).join(File::PATH_SEPARATOR),
      'RUBYOPT' => nil
    }

    Bundler.with_unbundled_env do
      sh env, 'gem', 'install', gem_path, '--local', '--no-document', '--install-dir', gem_home, '--ignore-dependencies'
      sh env, RbConfig.ruby, '-e', install_smoke_script
    end
  end
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

def install_smoke_script
  <<~RUBY
    gem 'rspec-rewind'
    require 'rspec/rewind/core'
    abort 'rspec-rewind version was not loaded' unless RSpec::Rewind::VERSION
  RUBY
end
