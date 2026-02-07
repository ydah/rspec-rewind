# frozen_string_literal: true

module RSpec
  module Rewind
    class RetryNotifier
      def initialize(configuration:, debug:, reporter_message:)
        @configuration = configuration
        @debug = debug
        @reporter_message = reporter_message
      end

      def notify_retry(event)
        debug("retry #{event.attempt}/#{event.retries} for #{event.example_id} in #{event.sleep_seconds.round(3)}s")
        @configuration.retry_callback&.call(event)
      rescue StandardError => e
        debug("retry callback failed: #{e.class}: #{e.message}")
      end

      def publish_flaky(event)
        @configuration.flaky_reporter.record(event)
        @configuration.flaky_callback&.call(event)
      rescue StandardError => e
        debug("failed to report flaky event: #{e.class}: #{e.message}")
      end

      def show_failure_message(exception)
        @reporter_message.call("[rspec-rewind] #{exception.class}: #{exception.message}")
      end

      private

      def debug(message)
        @debug.call(message)
      end
    end
  end
end
