# frozen_string_literal: true

module RSpec
  module Rewind
    class Runner
      def initialize(example:, configuration:)
        @example = example
        @configuration = configuration
      end

      def run(retries: nil, backoff: nil, wait: nil, retry_on: nil, skip_retry_on: nil, retry_if: nil)
        resolved_retries = components.retry_count_resolver.resolve(explicit_retries: retries)
        return @example.run if resolved_retries <= 0

        total_attempts = resolved_retries + 1
        attempt = 1

        while attempt <= total_attempts
          exception, duration, raised = components.attempt_runner.run(
            run_target: @example,
            exception_source: example_source
          )

          if exception.nil?
            if attempt > 1
              components.flaky_transition.perform(attempt: attempt, retries: resolved_retries, duration: duration)
            end
            return
          end

          retry_number = attempt
          unless components.retry_gate.allow?(
            exception: exception,
            retry_number: retry_number,
            resolved_retries: resolved_retries,
            retry_on: retry_on,
            skip_retry_on: skip_retry_on,
            retry_if: retry_if,
            example_id: example_id
          )
            raise exception if raised

            return
          end

          components.retry_transition.perform(
            retry_number: retry_number,
            resolved_retries: resolved_retries,
            duration: duration,
            exception: exception,
            backoff: backoff,
            wait: wait,
            example_source: example_source
          )

          attempt += 1
        end
      end

      private

      def example_source
        return @example.example if @example.respond_to?(:example) && @example.example

        @example
      end

      def example_metadata
        source = example_source
        return {} unless source.respond_to?(:metadata)

        source.metadata || {}
      end

      def example_id
        source = example_source
        source.respond_to?(:id) ? source.id : 'unknown'
      end

      def components
        @components ||= RunnerComponents.new(
          example: @example,
          configuration: @configuration,
          example_source: example_source,
          metadata: example_metadata,
          debug: method(:debug),
          reporter_message: method(:reporter_message)
        )
      end

      def reporter_message(message)
        if defined?(::RSpec) && ::RSpec.respond_to?(:configuration)
          reporter = ::RSpec.configuration.reporter
          reporter&.message(message)
        end
      rescue StandardError
        warn(message)
      end

      def debug(message)
        return unless @configuration.verbose

        reporter_message("[rspec-rewind] #{message}")
      end
    end
  end
end
