# frozen_string_literal: true

require 'rspec/core'
require 'time'

require_relative 'version'
require_relative 'backoff'
require_relative 'retry_budget'
require_relative 'retry_summary'
require_relative 'flaky_reporter'
require_relative 'matcher_validation'
require_relative 'configuration_validation'
require_relative 'configuration'
require_relative 'example_context'
require_relative 'event'
require_relative 'failure_fingerprint'
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
require_relative 'runner_component_factory'
require_relative 'rspec_adapter'
require_relative 'example_state_resetter'
require_relative 'retry_policy'
require_relative 'retry_decision'
require_relative 'runner'
require_relative 'example_methods'
require_relative 'api'

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

        warn_on_retry_gem_conflict

        ::RSpec::Core::Example.include(ExampleMethods)
        ::RSpec::Core::Example::Procsy.include(ExampleMethods) if defined?(::RSpec::Core::Example::Procsy)

        ::RSpec.configure do |config|
          config.before(:suite) do
            RSpec::Rewind.prepare_suite!
          end

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
        lifecycle_error = reporter_lifecycle_error(reporter)

        publish_retry_summary
        enforce_flaky_threshold!
        raise lifecycle_error if lifecycle_error && configuration.strict_callbacks
      end

      def prepare_suite!
        configuration.retry_summary.reset!
        configuration.freeze if configuration.freeze_configuration_at_suite_start
      end

      def publish_retry_summary
        return unless configuration.display_retry_summary

        summary = configuration.retry_summary.to_message(budget: configuration.retry_budget)
        ::RSpec.configuration.reporter.message(summary)
      rescue StandardError
        nil
      end

      def enforce_flaky_threshold!
        count = configuration.retry_summary.flaky_examples
        return unless (configuration.fail_on_flaky && count.positive?) || threshold_exceeded?(count)

        raise FlakyThresholdExceeded, "rspec-rewind observed #{count} flaky example(s)"
      end

      def threshold_exceeded?(count)
        max = configuration.max_flaky_examples
        !max.nil? && count > max
      end

      def warn_on_retry_gem_conflict
        return unless configuration.detect_retry_gem_conflicts
        return unless Gem.loaded_specs.key?('rspec-retry') || defined?(::RSpec::Retry)

        warn '[rspec-rewind] rspec-retry appears to be loaded; multiple retry hooks can interfere'
      end

      private

      def reporter_lifecycle_error(reporter)
        %i[flush close].filter_map do |method_name|
          invoke_reporter_lifecycle(reporter, method_name)
        end.first
      end

      def invoke_reporter_lifecycle(reporter, method_name)
        return nil unless reporter.respond_to?(method_name)

        reporter.public_send(method_name)
        nil
      rescue StandardError => e
        warn "[rspec-rewind] flaky reporter #{method_name} failed: #{e.class}: #{e.message}"
        e
      end
    end
  end
end
