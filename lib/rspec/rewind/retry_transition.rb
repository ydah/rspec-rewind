# frozen_string_literal: true

module RSpec
  module Rewind
    SleepMeasurement = Struct.new(
      :scheduled,
      :actual,
      keyword_init: true
    )

    class RetryTransition
      def initialize(configuration:, retry_delay_resolver:, event_builder:, notifier:, state_resetter:, sleep:)
        @configuration = configuration
        @retry_delay_resolver = retry_delay_resolver
        @event_builder = event_builder
        @notifier = notifier
        @state_resetter = state_resetter
        @sleep = sleep
      end

      def perform(
        retry_number:,
        resolved_retries:,
        duration:,
        exception:,
        backoff:,
        wait:,
        example_source:,
        total_duration: nil,
        attempt_durations: nil,
        sleep_total: 0.0,
        failure_fingerprint: nil,
        budget_decision: nil,
        policy_decision: nil
      )
        sleep_seconds = @retry_delay_resolver.resolve(
          retry_number: retry_number,
          backoff: backoff,
          wait: wait,
          exception: exception,
          resolved_retries: resolved_retries,
          previous_sleep_seconds: sleep_total,
          failure_fingerprint: failure_fingerprint
        )

        scheduled_event = build_event(
          retry_number: retry_number,
          resolved_retries: resolved_retries,
          duration: duration,
          exception: exception,
          sleep_seconds: sleep_seconds,
          total_duration: total_duration,
          attempt_durations: attempt_durations,
          sleep_total: sleep_total,
          scheduled_sleep_seconds: sleep_seconds,
          actual_sleep_seconds: nil,
          budget_decision: budget_decision,
          policy_decision: policy_decision
        )
        @notifier.notify_before_retry(scheduled_event)
        @notifier.show_failure_message(exception) if @configuration.display_retry_failure_messages
        @state_resetter.reset(example_source)
        actual_sleep_seconds = sleep_if_needed(sleep_seconds)

        event = build_event(
          retry_number: retry_number,
          resolved_retries: resolved_retries,
          duration: duration,
          exception: exception,
          sleep_seconds: sleep_seconds,
          total_duration: total_duration,
          attempt_durations: attempt_durations,
          sleep_total: sleep_total + actual_sleep_seconds,
          scheduled_sleep_seconds: sleep_seconds,
          actual_sleep_seconds: actual_sleep_seconds,
          budget_decision: budget_decision,
          policy_decision: policy_decision
        )

        @notifier.notify_retry(event)
        @notifier.notify_after_retry(event)

        SleepMeasurement.new(scheduled: sleep_seconds, actual: actual_sleep_seconds)
      end

      def publish_not_retried(
        retry_number:,
        resolved_retries:,
        duration:,
        exception:,
        decision:,
        total_duration: nil,
        attempt_durations: nil,
        sleep_total: 0.0
      )
        policy_decision = decision.policy_decision
        event = @event_builder.build(
          status: :not_retried,
          retry_reason: :exception,
          decision_reason: decision.reason,
          attempt: retry_number,
          retries: resolved_retries,
          duration: duration,
          total_duration: total_duration,
          attempt_durations: attempt_durations,
          sleep_seconds: 0.0,
          scheduled_sleep_seconds: 0.0,
          actual_sleep_seconds: 0.0,
          sleep_total: sleep_total,
          budget_decision: decision.budget_decision,
          matched_retry_on: policy_decision&.matched_retry_on,
          matched_skip_retry_on: policy_decision&.matched_skip_retry_on,
          matcher_error: policy_decision&.matcher_error,
          exception: exception
        )

        @notifier.publish_not_retried(event)
      end

      private

      def build_event(
        retry_number:,
        resolved_retries:,
        duration:,
        exception:,
        sleep_seconds:,
        total_duration:,
        attempt_durations:,
        sleep_total:,
        scheduled_sleep_seconds:,
        actual_sleep_seconds:,
        budget_decision:,
        policy_decision:
      )
        @event_builder.build(
          status: :retrying,
          retry_reason: :exception,
          attempt: retry_number,
          retries: resolved_retries,
          duration: duration,
          total_duration: total_duration,
          attempt_durations: attempt_durations,
          sleep_seconds: sleep_seconds,
          scheduled_sleep_seconds: scheduled_sleep_seconds,
          actual_sleep_seconds: actual_sleep_seconds,
          sleep_total: sleep_total,
          budget_decision: budget_decision,
          matched_retry_on: policy_decision&.matched_retry_on,
          matched_skip_retry_on: policy_decision&.matched_skip_retry_on,
          matcher_error: policy_decision&.matcher_error,
          exception: exception
        )
      end

      def sleep_if_needed(seconds)
        return 0.0 unless seconds.positive?

        started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        @sleep.call(seconds)
        Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at
      end
    end
  end
end
