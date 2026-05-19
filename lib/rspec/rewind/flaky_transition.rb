# frozen_string_literal: true

module RSpec
  module Rewind
    class FlakyTransition
      def initialize(event_builder:, notifier:)
        @event_builder = event_builder
        @notifier = notifier
      end

      def perform(
        attempt:,
        retries:,
        duration:,
        exception:,
        total_duration: nil,
        attempt_durations: nil,
        first_failure_duration: nil,
        sleep_total: 0.0,
        budget_decision: nil
      )
        event = @event_builder.build(
          status: :flaky,
          retry_reason: :exception,
          attempt: attempt,
          retries: retries,
          duration: duration,
          total_duration: total_duration,
          attempt_durations: attempt_durations,
          first_failure_duration: first_failure_duration,
          sleep_seconds: 0.0,
          scheduled_sleep_seconds: 0.0,
          actual_sleep_seconds: 0.0,
          sleep_total: sleep_total,
          budget_decision: budget_decision,
          exception: exception
        )

        @notifier.publish_flaky(event)
      end
    end
  end
end
