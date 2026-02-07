# frozen_string_literal: true

require 'rspec/core'
require 'time'

require_relative 'rewind/version'
require_relative 'rewind/backoff'
require_relative 'rewind/retry_budget'
require_relative 'rewind/flaky_reporter'
require_relative 'rewind/configuration'
require_relative 'rewind/event'
require_relative 'rewind/retry_event_builder'
require_relative 'rewind/retry_notifier'
require_relative 'rewind/example_state_resetter'
require_relative 'rewind/retry_decision'
require_relative 'rewind/runner'
require_relative 'rewind/example_methods'

module RSpec
  module Rewind
    class << self
      def configuration
        @configuration ||= Configuration.new
      end

      def configure
        yield(configuration)
      end

      def reset_configuration!
        @configuration = Configuration.new
      end

      def install!
        return if @installed

        ::RSpec::Core::Example.include(ExampleMethods)
        ::RSpec::Core::Example::Procsy.include(ExampleMethods) if defined?(::RSpec::Core::Example::Procsy)

        ::RSpec.configure do |config|
          config.around(:each) do |example|
            if example.metadata[:rewind] == false || example.metadata[:retry] == false
              example.run
            else
              example.run_with_rewind
            end
          end
        end

        @installed = true
      end
    end
  end
end

RSpec::Rewind.install!
