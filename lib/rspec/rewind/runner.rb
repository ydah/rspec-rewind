# frozen_string_literal: true

module RSpec
  module Rewind
    class Runner
      def initialize(example:, configuration:)
        @example = example
        @configuration = configuration
        @context = ExampleContext.new(example: example)
        @logger = RunnerLogger.new(configuration: configuration, warn_output: method(:warn))
      end

      def run(retries: nil, backoff: nil, wait: nil, retry_on: nil, skip_retry_on: nil, retry_if: nil)
        resolved_retries = components.retry_count_resolver.resolve(explicit_retries: retries)
        return @example.run if resolved_retries <= 0

        total_attempts = resolved_retries + 1
        attempt = 1

        while attempt <= total_attempts
          exception, duration, raised = components.attempt_runner.run(
            run_target: @example,
            exception_source: @context.source
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
            example_id: @context.id
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
            example_source: @context.source
          )

          attempt += 1
        end
      end

      private

      def components
        @components ||= RunnerComponents.new(
          example: @example,
          configuration: @configuration,
          context: @context,
          logger: @logger
        )
      end
    end
  end
end
