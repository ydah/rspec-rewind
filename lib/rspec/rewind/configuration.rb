# frozen_string_literal: true

module RSpec
  module Rewind
    class Configuration
      include MatcherValidation

      attr_reader :default_retries, :backoff, :retry_on, :skip_retry_on, :retry_if, :retry_callback, :flaky_callback,
                  :verbose, :display_retry_failure_messages, :clear_lets_on_failure, :retry_budget, :flaky_reporter

      def initialize
        self.default_retries = 0
        self.backoff = Backoff.fixed(0)
        self.retry_on = []
        self.skip_retry_on = []
        self.retry_if = nil
        self.retry_callback = nil
        self.flaky_callback = nil
        self.verbose = false
        self.display_retry_failure_messages = false
        self.clear_lets_on_failure = true
        self.retry_budget = nil
        self.flaky_reporter = FlakyReporter.null
      end

      def default_retries=(value)
        @default_retries = parse_non_negative_integer(value, source: 'default_retries')
      end

      def backoff=(value)
        @backoff = normalize_backoff(value)
      end

      def retry_on=(values)
        @retry_on = normalize_matchers(values, field: 'retry_on')
      end

      def skip_retry_on=(values)
        @skip_retry_on = normalize_matchers(values, field: 'skip_retry_on')
      end

      def retry_if=(callable)
        @retry_if = normalize_callable(callable, field: 'retry_if')
      end

      def retry_callback=(callable)
        @retry_callback = normalize_callable(callable, field: 'retry_callback')
      end

      def flaky_callback=(callable)
        @flaky_callback = normalize_callable(callable, field: 'flaky_callback')
      end

      def verbose=(value)
        @verbose = normalize_boolean(value, field: 'verbose')
      end

      def display_retry_failure_messages=(value)
        @display_retry_failure_messages = normalize_boolean(value, field: 'display_retry_failure_messages')
      end

      def clear_lets_on_failure=(value)
        @clear_lets_on_failure = normalize_boolean(value, field: 'clear_lets_on_failure')
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

      private

      def parse_non_negative_integer(value, source:)
        parsed = begin
          Integer(value)
        rescue TypeError, ArgumentError
          raise ArgumentError, "#{source} must be a non-negative integer"
        end

        raise ArgumentError, "#{source} must be >= 0" if parsed.negative?

        parsed
      end

      def normalize_backoff(value)
        if value.is_a?(Numeric)
          number = Float(value)
          raise ArgumentError, 'backoff must be >= 0' if number.negative?

          return number
        end

        return value if value.respond_to?(:call)

        raise ArgumentError, 'backoff must be a non-negative numeric value or callable'
      end

      def normalize_callable(callable, field:)
        return nil if callable.nil?

        return callable if callable.respond_to?(:call)

        raise ArgumentError, "#{field} must be nil or callable"
      end

      def normalize_boolean(value, field:)
        return value if [true, false].include?(value)

        raise ArgumentError, "#{field} must be true or false"
      end
    end
  end
end
