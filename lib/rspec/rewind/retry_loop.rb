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
        flaky_transition:,
        clock: nil
      )
        @example = example
        @context = context
        @retry_count_resolver = retry_count_resolver
        @attempt_runner = attempt_runner
        @retry_gate = retry_gate
        @retry_transition = retry_transition
        @flaky_transition = flaky_transition
        @clock = clock || -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) }
      end

      def run(retries:, backoff:, wait:, retry_on:, skip_retry_on:, retry_if:)
        resolved_retries = @retry_count_resolver.resolve(explicit_retries: retries)
        return @example.run if resolved_retries <= 0

        total_attempts = resolved_retries + 1
        attempt = 1
        first_exception = nil
        first_failure_duration = nil
        attempt_durations = []
        sleep_total = 0.0
        started_at = monotonic_time

        while attempt <= total_attempts
          exception, duration, raised = @attempt_runner.run(
            run_target: @example,
            exception_source: @context.source
          )
          attempt_durations << duration

          if exception.nil?
            if attempt > 1
              @flaky_transition.perform(
                attempt: attempt,
                retries: resolved_retries,
                duration: duration,
                exception: first_exception,
                total_duration: monotonic_time - started_at,
                attempt_durations: attempt_durations.dup,
                first_failure_duration: first_failure_duration,
                sleep_total: sleep_total
              )
            end
            return
          end

          first_exception ||= exception
          first_failure_duration ||= duration
          retry_number = attempt
          decision = @retry_gate.decision(
            exception: exception,
            retry_number: retry_number,
            resolved_retries: resolved_retries,
            retry_on: retry_on,
            skip_retry_on: skip_retry_on,
            retry_if: retry_if,
            example_id: @context.id,
            elapsed_time: monotonic_time - started_at,
            sleep_total: sleep_total
          )
          unless decision.allowed?
            @retry_transition.publish_not_retried(
              retry_number: retry_number,
              resolved_retries: resolved_retries,
              duration: duration,
              exception: exception,
              decision: decision,
              total_duration: monotonic_time - started_at,
              attempt_durations: attempt_durations.dup,
              sleep_total: sleep_total
            )
            raise exception if raised

            return
          end

          sleep_measurement = @retry_transition.perform(
            retry_number: retry_number,
            resolved_retries: resolved_retries,
            duration: duration,
            exception: exception,
            backoff: backoff,
            wait: wait,
            example_source: @context.source,
            total_duration: monotonic_time - started_at,
            attempt_durations: attempt_durations.dup,
            sleep_total: sleep_total,
            failure_fingerprint: failure_fingerprint(exception),
            budget_decision: decision.budget_decision,
            policy_decision: decision.policy_decision
          )
          sleep_total += sleep_measurement.actual

          attempt += 1
        end
      end

      private

      def monotonic_time
        @clock.call
      end

      def failure_fingerprint(exception)
        [exception.class.name, exception.message, exception.backtrace&.first].join(':')
      end
    end
  end
end
