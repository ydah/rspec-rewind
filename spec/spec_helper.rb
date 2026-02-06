# frozen_string_literal: true

if ENV['COVERAGE'] == '1'
  require 'simplecov'

  SimpleCov.start do
    enable_coverage :branch
    add_filter '/spec/'
    minimum_coverage line: 90, branch: 75
    minimum_coverage_by_file 80
  end
end

require 'rspec/rewind'

RSpec::Rewind.reset_configuration!

RSpec.configure do |config|
  config.disable_monkey_patching!
  config.example_status_persistence_file_path = '.rspec_status'

  config.define_derived_metadata do |metadata|
    metadata[:rewind] = false unless metadata.key?(:rewind)
  end

  config.expect_with :rspec do |expectations|
    expectations.syntax = :expect
  end
end
