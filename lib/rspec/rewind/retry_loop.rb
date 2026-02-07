# frozen_string_literal: true

module RSpec
  module Rewind
    class RetryLoop
      def initialize(
        example:,
        context:,
        retry_count_resolver:,
        attempt_runner:,
        retry_gate:,
        retry_transition:,
        flaky_transition:
      )
        @example = example
        @context = context
        @retry_count_resolver = retry_count_resolver
        @attempt_runner = attempt_runner
        @retry_gate = retry_gate
        @retry_transition = retry_transition
        @flaky_transition = flaky_transition
      end

      def run(retries:, backoff:, wait:, retry_on:, skip_retry_on:, retry_if:)
        resolved_retries = @retry_count_resolver.resolve(explicit_retries: retries)
        return @example.run if resolved_retries <= 0

        total_attempts = resolved_retries + 1
        attempt = 1

        while attempt <= total_attempts
          exception, duration, raised = @attempt_runner.run(
            run_target: @example,
            exception_source: @context.source
          )

          if exception.nil?
            @flaky_transition.perform(attempt: attempt, retries: resolved_retries, duration: duration) if attempt > 1
            return
          end

          retry_number = attempt
          unless @retry_gate.allow?(
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

          @retry_transition.perform(
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
    end
  end
end
