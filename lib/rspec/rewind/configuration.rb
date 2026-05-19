# frozen_string_literal: true

module RSpec
  module Rewind
    class Configuration
      include MatcherValidation
      include ConfigurationValidation

      attr_reader :default_retries, :backoff, :retry_on, :skip_retry_on, :retry_if, :retry_callback, :flaky_callback,
                  :not_retried_callback, :before_retry, :after_retry, :verbose, :display_retry_failure_messages,
                  :display_retry_backtrace_top, :clear_lets_on_failure, :retry_budget, :flaky_reporter,
                  :flaky_report_path, :retry_if_mode, :retry_on_default, :report_retry_events,
                  :strict_callbacks, :strict_callable_arity, :metadata_report_keys, :max_retries,
                  :max_elapsed_time, :max_total_sleep, :sleeper, :clock, :dry_run,
                  :strict_matcher_validation, :reset_failure_policy, :retry_summary,
                  :display_retry_summary, :fail_on_flaky, :max_flaky_examples,
                  :freeze_configuration_at_suite_start, :warn_on_delay_conflict,
                  :detect_retry_gem_conflicts

      def initialize
        self.default_retries = 0
        self.backoff = Backoff.fixed(0)
        self.strict_matcher_validation = false
        self.retry_on = []
        self.skip_retry_on = []
        self.retry_if = nil
        self.retry_callback = nil
        self.flaky_callback = nil
        self.not_retried_callback = nil
        self.before_retry = nil
        self.after_retry = nil
        self.retry_summary = RetrySummary.new
        self.verbose = false
        self.display_retry_failure_messages = false
        self.display_retry_backtrace_top = false
        self.display_retry_summary = false
        self.fail_on_flaky = false
        self.max_flaky_examples = nil
        self.freeze_configuration_at_suite_start = false
        self.warn_on_delay_conflict = true
        self.detect_retry_gem_conflicts = true
        self.clear_lets_on_failure = true
        self.reset_failure_policy = :raise
        self.retry_budget = nil
        self.flaky_reporter = FlakyReporter.null
        self.flaky_report_path = nil
        self.retry_if_mode = :override
        self.retry_on_default = :all
        self.report_retry_events = false
        self.strict_callbacks = false
        self.strict_callable_arity = false
        self.metadata_report_keys = []
        self.max_retries = nil
        self.max_elapsed_time = nil
        self.max_total_sleep = nil
        self.sleeper = Kernel.method(:sleep)
        self.clock = -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) }
        self.dry_run = false
      end

      def default_retries=(value)
        @default_retries = parse_non_negative_integer(value, source: 'default_retries')
      end

      def backoff=(value)
        @backoff = normalize_backoff(value)
      end

      def retry_on=(values)
        @retry_on = normalize_matchers(
          values,
          field: 'retry_on',
          strict_exception_matchers: @strict_matcher_validation
        )
      end

      def skip_retry_on=(values)
        @skip_retry_on = normalize_matchers(
          values,
          field: 'skip_retry_on',
          strict_exception_matchers: @strict_matcher_validation
        )
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

      def not_retried_callback=(callable)
        @not_retried_callback = normalize_callable(callable, field: 'not_retried_callback')
      end

      def before_retry=(callable)
        @before_retry = normalize_callable(callable, field: 'before_retry')
      end

      def after_retry=(callable)
        @after_retry = normalize_callable(callable, field: 'after_retry')
      end

      def retry_summary=(summary)
        unless summary.respond_to?(:record) && summary.respond_to?(:reset!)
          raise ArgumentError, 'retry_summary must respond to #record and #reset!'
        end

        @retry_summary = summary
      end

      def verbose=(value)
        @verbose = normalize_boolean(value, field: 'verbose')
      end

      def display_retry_failure_messages=(value)
        @display_retry_failure_messages = normalize_boolean(value, field: 'display_retry_failure_messages')
      end

      def display_retry_backtrace_top=(value)
        @display_retry_backtrace_top = normalize_boolean(value, field: 'display_retry_backtrace_top')
      end

      def display_retry_summary=(value)
        @display_retry_summary = normalize_boolean(value, field: 'display_retry_summary')
      end

      def fail_on_flaky=(value)
        @fail_on_flaky = normalize_boolean(value, field: 'fail_on_flaky')
      end

      def max_flaky_examples=(value)
        @max_flaky_examples = value.nil? ? nil : parse_non_negative_integer(value, source: 'max_flaky_examples')
      end

      def freeze_configuration_at_suite_start=(value)
        @freeze_configuration_at_suite_start = normalize_boolean(value, field: 'freeze_configuration_at_suite_start')
      end

      def warn_on_delay_conflict=(value)
        @warn_on_delay_conflict = normalize_boolean(value, field: 'warn_on_delay_conflict')
      end

      def detect_retry_gem_conflicts=(value)
        @detect_retry_gem_conflicts = normalize_boolean(value, field: 'detect_retry_gem_conflicts')
      end

      def clear_lets_on_failure=(value)
        @clear_lets_on_failure = normalize_boolean(value, field: 'clear_lets_on_failure')
      end

      def reset_failure_policy=(mode)
        @reset_failure_policy = normalize_symbol(mode, allowed: %i[raise continue], field: 'reset_failure_policy')
      end

      def retry_budget=(limit_or_budget)
        @retry_budget =
          if custom_budget?(limit_or_budget)
            limit_or_budget
          else
            RetryBudget.new(limit_or_budget)
          end
      end

      def flaky_reporter=(reporter)
        normalized = reporter || FlakyReporter.null
        raise ArgumentError, 'flaky_reporter must respond to #record' unless normalized.respond_to?(:record)

        @flaky_reporter = normalized
        @flaky_report_path = reporter_path(normalized)
      end

      def flaky_report_path=(path)
        @flaky_report_path = path&.to_s
        @flaky_reporter = @flaky_report_path.nil? ? FlakyReporter.null : FlakyReporter.jsonl(@flaky_report_path)
      end

      def retry_if_mode=(mode)
        @retry_if_mode = normalize_symbol(mode, allowed: %i[override and or], field: 'retry_if_mode')
      end

      def retry_on_default=(mode)
        @retry_on_default = normalize_symbol(mode, allowed: %i[all standard_errors none], field: 'retry_on_default')
      end

      def report_retry_events=(value)
        @report_retry_events = normalize_boolean(value, field: 'report_retry_events')
      end

      def strict_callbacks=(value)
        @strict_callbacks = normalize_boolean(value, field: 'strict_callbacks')
      end

      def strict_callable_arity=(value)
        @strict_callable_arity = normalize_boolean(value, field: 'strict_callable_arity')
      end

      def strict_matcher_validation=(value)
        @strict_matcher_validation = normalize_boolean(value, field: 'strict_matcher_validation')
      end

      def metadata_report_keys=(values)
        @metadata_report_keys = Array(values).flatten.compact.map(&:to_sym)
      end

      def max_retries=(value)
        @max_retries = value.nil? ? nil : parse_non_negative_integer(value, source: 'max_retries')
      end

      def max_elapsed_time=(value)
        @max_elapsed_time = value.nil? ? nil : normalize_non_negative_float(value, field: 'max_elapsed_time')
      end

      def max_total_sleep=(value)
        @max_total_sleep = value.nil? ? nil : normalize_non_negative_float(value, field: 'max_total_sleep')
      end

      def sleeper=(callable)
        @sleeper = normalize_callable(callable, field: 'sleeper')
      end

      def clock=(callable)
        @clock = normalize_callable(callable, field: 'clock')
      end

      def dry_run=(value)
        @dry_run = normalize_boolean(value, field: 'dry_run')
      end

      def freeze
        freeze_mutable_policy_state
        super
      end

      def snapshot
        copy = dup
        copy.instance_variable_set(:@retry_on, @retry_on.dup)
        copy.instance_variable_set(:@skip_retry_on, @skip_retry_on.dup)
        copy.instance_variable_set(:@metadata_report_keys, @metadata_report_keys.dup)
        copy.freeze
      end

      private

      def freeze_mutable_policy_state
        @retry_on.freeze
        @skip_retry_on.freeze
        @metadata_report_keys.freeze
      end

      def reporter_path(reporter)
        return nil unless reporter.respond_to?(:path)

        path = reporter.path
        path&.to_s
      end
    end
  end
end
