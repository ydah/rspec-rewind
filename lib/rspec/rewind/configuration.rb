# frozen_string_literal: true

module RSpec
  module Rewind
    class Configuration
      attr_accessor :default_retries,
                    :backoff,
                    :retry_on,
                    :skip_retry_on,
                    :retry_if,
                    :retry_callback,
                    :flaky_callback,
                    :verbose,
                    :display_retry_failure_messages,
                    :clear_lets_on_failure

      attr_reader :retry_budget, :flaky_reporter

      def initialize
        @default_retries = 0
        @backoff = Backoff.fixed(0)
        @retry_on = []
        @skip_retry_on = []
        @retry_if = nil
        @retry_callback = nil
        @flaky_callback = nil
        @verbose = false
        @display_retry_failure_messages = false
        @clear_lets_on_failure = true
        @retry_budget = RetryBudget.new(nil)
        @flaky_reporter = FlakyReporter.null
      end

      def retry_budget=(limit_or_budget)
        @retry_budget =
          if limit_or_budget.is_a?(RetryBudget)
            limit_or_budget
          else
            RetryBudget.new(limit_or_budget)
          end
      end

      def flaky_reporter=(reporter)
        @flaky_reporter = reporter || FlakyReporter.null
      end

      def flaky_report_path=(path)
        @flaky_reporter = path.nil? ? FlakyReporter.null : FlakyReporter.jsonl(path)
      end
    end
  end
end
