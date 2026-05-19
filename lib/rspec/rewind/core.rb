# frozen_string_literal: true

require 'rspec/core'
require 'time'

require_relative 'version'
require_relative 'backoff'
require_relative 'retry_budget'
require_relative 'flaky_reporter'
require_relative 'matcher_validation'
require_relative 'configuration_validation'
require_relative 'configuration'
require_relative 'example_context'
require_relative 'event'
require_relative 'retry_count_resolver'
require_relative 'retry_delay_resolver'
require_relative 'retry_event_builder'
require_relative 'retry_notifier'
require_relative 'flaky_transition'
require_relative 'attempt_runner'
require_relative 'retry_transition'
require_relative 'retry_gate'
require_relative 'retry_loop'
require_relative 'runner_logger'
require_relative 'runner_components'
require_relative 'rspec_adapter'
require_relative 'example_state_resetter'
require_relative 'retry_policy'
require_relative 'retry_decision'
require_relative 'runner'
require_relative 'example_methods'

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
        return false if installed?

        ::RSpec::Core::Example.include(ExampleMethods)
        ::RSpec::Core::Example::Procsy.include(ExampleMethods) if defined?(::RSpec::Core::Example::Procsy)

        ::RSpec.configure do |config|
          config.around(:each) do |example|
            if example.metadata[:rewind] == false
              example.run
            else
              example.run_with_rewind
            end
          end

          config.after(:suite) do
            RSpec::Rewind.close_reporter
          end
        end

        @installed = true
      end

      def installed?
        !!@installed
      end

      def auto_install_disabled?
        %w[0 false no off].include?(ENV.fetch('RSPEC_REWIND_AUTO_INSTALL', '').downcase)
      end

      def close_reporter
        reporter = configuration.flaky_reporter
        reporter.flush if reporter.respond_to?(:flush)
        reporter.close if reporter.respond_to?(:close)
      end
    end
  end
end
