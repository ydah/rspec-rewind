# frozen_string_literal: true

module RSpec
  module Rewind
    class FlakyTransition
      def initialize(event_builder:, notifier:)
        @event_builder = event_builder
        @notifier = notifier
      end

      def perform(attempt:, retries:, duration:)
        event = @event_builder.build(
          status: :flaky,
          retry_reason: nil,
          attempt: attempt,
          retries: retries,
          duration: duration,
          sleep_seconds: 0.0,
          exception: nil
        )

        @notifier.publish_flaky(event)
      end
    end
  end
end
