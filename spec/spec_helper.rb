# frozen_string_literal: true

require "rspec/rewind"

RSpec::Rewind.reset_configuration!

RSpec.configure do |config|
  config.disable_monkey_patching!
  config.example_status_persistence_file_path = ".rspec_status"

  config.define_derived_metadata do |metadata|
    metadata[:rewind] = false unless metadata.key?(:rewind)
  end

  config.expect_with :rspec do |expectations|
    expectations.syntax = :expect
  end
end
