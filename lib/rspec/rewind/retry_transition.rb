# frozen_string_literal: true

module RSpec
  module Rewind
    SleepMeasurement = Struct.new(:scheduled, :actual, keyword_init: true)

    class RetryTransition
      def initialize(
        configuration:,
        retry_delay_resolver:,
        event_builder:,
        notifier:,
        state_resetter:,
        sleep:,
        clock: nil
      )
        @configuration = configuration
        @retry_delay_resolver = retry_delay_resolver
        @event_builder = event_builder
        @notifier = notifier
        @state_resetter = state_resetter
        @sleep = sleep
        @clock = clock || -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) }
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

        event_context = {
          retry_number: retry_number,
          resolved_retries: resolved_retries,
          duration: duration,
          sleep_seconds: sleep_seconds,
          total_duration: total_duration,
          attempt_durations: attempt_durations,
          sleep_total: sleep_total,
          budget_decision: budget_decision,
          policy_decision: policy_decision
        }

        scheduled_event = build_event(
          exception: exception,
          scheduled_sleep_seconds: sleep_seconds,
          actual_sleep_seconds: nil,
          **event_context
        )
        @notifier.notify_before_retry(scheduled_event)
        @notifier.show_failure_message(exception) if @configuration.display_retry_failure_messages
        reset_example_state(
          example_source: example_source,
          retry_exception: exception,
          **event_context
        )
        actual_sleep_seconds = sleep_if_needed(sleep_seconds)

        event = build_event(
          exception: exception,
          scheduled_sleep_seconds: sleep_seconds,
          actual_sleep_seconds: actual_sleep_seconds,
          **event_context.merge(sleep_total: sleep_total + actual_sleep_seconds)
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

      def reset_example_state(example_source:, retry_exception:, **event_context)
        reset_result = @state_resetter.reset(example_source)
        return unless reset_result == false

        publish_reset_failed(
          reset_exception: state_reset_exception || retry_exception,
          **event_context
        )
      rescue StandardError => e
        publish_reset_failed(
          reset_exception: e,
          **event_context
        )
        raise
      end

      def publish_reset_failed(reset_exception:, **event_context)
        policy_decision = event_context[:policy_decision]
        sleep_seconds = event_context[:sleep_seconds]
        event = @event_builder.build(
          status: :reset_failed,
          retry_reason: :state_reset,
          decision_reason: :state_reset_failed,
          attempt: event_context[:retry_number],
          retries: event_context[:resolved_retries],
          duration: event_context[:duration],
          total_duration: event_context[:total_duration],
          attempt_durations: event_context[:attempt_durations],
          sleep_seconds: sleep_seconds,
          scheduled_sleep_seconds: sleep_seconds,
          actual_sleep_seconds: 0.0,
          sleep_total: event_context[:sleep_total],
          budget_decision: event_context[:budget_decision],
          matched_retry_on: policy_decision&.matched_retry_on,
          matched_skip_retry_on: policy_decision&.matched_skip_retry_on,
          matcher_error: policy_decision&.matcher_error,
          exception: reset_exception
        )

        @notifier.publish_reset_failed(event)
      end

      def state_reset_exception
        return nil unless @state_resetter.respond_to?(:last_exception)

        @state_resetter.last_exception
      end

      def build_event(exception:, scheduled_sleep_seconds:, actual_sleep_seconds:, **event_context)
        policy_decision = event_context[:policy_decision]
        @event_builder.build(
          status: :retrying,
          retry_reason: :exception,
          attempt: event_context[:retry_number],
          retries: event_context[:resolved_retries],
          duration: event_context[:duration],
          total_duration: event_context[:total_duration],
          attempt_durations: event_context[:attempt_durations],
          sleep_seconds: event_context[:sleep_seconds],
          scheduled_sleep_seconds: scheduled_sleep_seconds,
          actual_sleep_seconds: actual_sleep_seconds,
          sleep_total: event_context[:sleep_total],
          budget_decision: event_context[:budget_decision],
          matched_retry_on: policy_decision&.matched_retry_on,
          matched_skip_retry_on: policy_decision&.matched_skip_retry_on,
          matcher_error: policy_decision&.matcher_error,
          exception: exception
        )
      end

      def sleep_if_needed(seconds)
        return 0.0 unless seconds.positive?

        started_at = monotonic_time
        @sleep.call(seconds)
        monotonic_time - started_at
      end

      def monotonic_time
        @clock.call
      end
    end
  end
end
