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
        publish_retry_report(event) if @configuration.report_retry_events
        invoke_callback(@configuration.retry_callback, event, 'retry callback')
      end

      def notify_before_retry(event)
        invoke_callback(@configuration.before_retry, event, 'before_retry hook')
      end

      def notify_after_retry(event)
        invoke_callback(@configuration.after_retry, event, 'after_retry hook')
      end

      def publish_not_retried(event)
        debug("not retrying #{event.example_id}: #{event.decision_reason}")
        publish_retry_report(event) if @configuration.report_retry_events
        invoke_callback(@configuration.not_retried_callback, event, 'not_retried callback')
      rescue StandardError => e
        raise if @configuration.strict_callbacks

        debug("not_retried callback failed: #{e.class}: #{e.message}")
      end

      def publish_flaky(event)
        publish_flaky_report(event)
        invoke_callback(@configuration.flaky_callback, event, 'flaky callback')
      end

      def show_failure_message(exception)
        message = "[rspec-rewind] #{exception.class}: #{exception.message}"
        if @configuration.display_retry_backtrace_top && exception.backtrace&.first
          message = "#{message} (#{exception.backtrace.first})"
        end

        @reporter_message.call(message)
      end

      private

      def publish_retry_report(event)
        @configuration.flaky_reporter.record(event)
      rescue StandardError => e
        raise if @configuration.strict_callbacks

        debug("failed to record retry event: #{e.class}: #{e.message}")
      end

      def publish_flaky_report(event)
        @configuration.flaky_reporter.record(event)
      rescue StandardError => e
        raise if @configuration.strict_callbacks

        debug("failed to record flaky event: #{e.class}: #{e.message}")
      end

      def invoke_callback(callback, event, label)
        callback&.call(event)
      rescue StandardError => e
        raise if @configuration.strict_callbacks

        debug("#{label} failed: #{e.class}: #{e.message}")
      end

      def debug(message)
        @debug.call(message)
      end
    end
  end
end
