# frozen_string_literal: true

module RSpec
  module Rewind
    class FlakyThresholdExceeded < StandardError; end

    class RetrySummary
      attr_reader :retry_events, :flaky_examples, :not_retried_events, :reset_failed_events, :sleep_seconds

      def initialize
        reset!
      end

      def record(event)
        @mutex.synchronize do
          case event.status
          when :retrying
            @retry_events += 1
            @sleep_seconds += event.actual_sleep_seconds.to_f
          when :flaky
            @flaky_examples += 1
          when :not_retried
            @not_retried_events += 1
          when :reset_failed
            @reset_failed_events += 1
          end
        end
      end

      def reset!
        @mutex = Mutex.new
        @retry_events = 0
        @flaky_examples = 0
        @not_retried_events = 0
        @reset_failed_events = 0
        @sleep_seconds = 0.0
      end

      def to_message(budget:)
        parts = [
          "#{@flaky_examples} flaky examples",
          "#{@retry_events} retry attempts",
          "#{format('%.3f', @sleep_seconds)}s spent sleeping",
          "#{@not_retried_events} not retried",
          "#{@reset_failed_events} reset failures"
        ]
        parts << budget_message(budget)
        "[rspec-rewind] #{parts.compact.join(', ')}"
      end

      private

      def budget_message(budget)
        return nil unless budget.respond_to?(:used)

        limit = budget.respond_to?(:limit) ? budget.limit : nil
        limit.nil? ? "budget #{budget.used}/unlimited used" : "budget #{budget.used}/#{limit} used"
      end
    end
  end
end
