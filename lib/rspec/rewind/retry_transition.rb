# frozen_string_literal: true

module RSpec
  module Rewind
    class RetryTransition
      def initialize(configuration:, retry_delay_resolver:, event_builder:, notifier:, state_resetter:, sleep:)
        @configuration = configuration
        @retry_delay_resolver = retry_delay_resolver
        @event_builder = event_builder
        @notifier = notifier
        @state_resetter = state_resetter
        @sleep = sleep
      end

      def perform(retry_number:, resolved_retries:, duration:, exception:, backoff:, wait:, example_source:)
        sleep_seconds = @retry_delay_resolver.resolve(
          retry_number: retry_number,
          backoff: backoff,
          wait: wait,
          exception: exception
        )

        event = @event_builder.build(
          status: :retrying,
          retry_reason: :exception,
          attempt: retry_number,
          retries: resolved_retries,
          duration: duration,
          sleep_seconds: sleep_seconds,
          exception: exception
        )

        @notifier.notify_retry(event)
        @notifier.show_failure_message(exception) if @configuration.display_retry_failure_messages
        @state_resetter.reset(example_source)
        @sleep.call(sleep_seconds) if sleep_seconds.positive?
      end
    end
  end
end
