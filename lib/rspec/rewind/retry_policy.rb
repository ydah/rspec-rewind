# frozen_string_literal: true

module RSpec
  module Rewind
    class RetryPolicy
      include MatcherValidation

      def initialize(example:, configuration:, metadata:)
        @example = example
        @configuration = configuration
        @metadata = metadata || {}
      end

      def retry_allowed?(exception:, retry_on:, skip_retry_on:, retry_if:)
        decision(
          exception: exception,
          retry_on: retry_on,
          skip_retry_on: skip_retry_on,
          retry_if: retry_if
        ).allowed?
      end

      def decision(
        exception:,
        retry_on:,
        skip_retry_on:,
        retry_if:,
        retry_number: nil,
        resolved_retries: nil,
        budget_remaining: nil,
        elapsed_time: nil,
        sleep_total: nil
      )
        RetryDecision.new(
          exception: exception,
          example: @example,
          retry_on: effective_retry_on(retry_on),
          skip_retry_on: effective_skip_retry_on(skip_retry_on),
          retry_if: effective_retry_if(retry_if),
          retry_on_default: @configuration.retry_on_default,
          strict_callable_arity: @configuration.strict_callable_arity,
          context: retry_context(
            retry_number: retry_number,
            resolved_retries: resolved_retries,
            budget_remaining: budget_remaining,
            elapsed_time: elapsed_time,
            sleep_total: sleep_total,
            exception: exception
          )
        ).decision
      end

      private

      def effective_retry_on(explicit_retry_on)
        if retry_on_mode == :override
          return normalize_policy_matchers(@metadata[:rewind_retry_on], field: 'rewind_retry_on') +
                 normalize_policy_matchers(explicit_retry_on, field: 'retry_on')
        end

        normalize_policy_matchers(@configuration.retry_on, field: 'retry_on') +
          normalize_policy_matchers(@metadata[:rewind_retry_on], field: 'rewind_retry_on') +
          normalize_policy_matchers(explicit_retry_on, field: 'retry_on')
      end

      def effective_skip_retry_on(explicit_skip_retry_on)
        if skip_retry_on_mode == :override
          return normalize_policy_matchers(metadata_skip_retry_on, field: 'rewind_skip_retry_on') +
                 normalize_policy_matchers(explicit_skip_retry_on, field: 'skip_retry_on')
        end

        normalize_policy_matchers(@configuration.skip_retry_on, field: 'skip_retry_on') +
          normalize_policy_matchers(metadata_skip_retry_on, field: 'rewind_skip_retry_on') +
          normalize_policy_matchers(explicit_skip_retry_on, field: 'skip_retry_on')
      end

      def effective_retry_if(explicit_retry_if)
        predicates = [@configuration.retry_if, @metadata[:rewind_if], explicit_retry_if].compact
        predicates.each { |predicate| validate_callable!(predicate, field: 'retry_if') }

        case retry_if_mode
        when :and
          return nil if predicates.empty?

          ->(*args) { predicates.all? { |predicate| call_predicate(predicate, args) } }
        when :or
          return nil if predicates.empty?

          ->(*args) { predicates.any? { |predicate| call_predicate(predicate, args) } }
        else
          first_non_nil(explicit_retry_if, @metadata[:rewind_if], @configuration.retry_if)
        end
      end

      def metadata_skip_retry_on
        @metadata[:rewind_skip_retry_on]
      end

      def normalize_policy_matchers(values, field:)
        normalize_matchers(
          values,
          field: field,
          strict_exception_matchers: @configuration.strict_matcher_validation
        )
      end

      def retry_if_mode
        normalize_mode(
          @metadata[:rewind_if_mode],
          allowed: %i[override and or],
          fallback: @configuration.retry_if_mode,
          field: 'rewind_if_mode'
        )
      end

      def retry_on_mode
        normalize_mode(
          @metadata[:rewind_retry_on_mode],
          allowed: %i[append override],
          fallback: :append,
          field: 'rewind_retry_on_mode'
        )
      end

      def skip_retry_on_mode
        normalize_mode(
          @metadata[:rewind_skip_retry_on_mode],
          allowed: %i[append override],
          fallback: :append,
          field: 'rewind_skip_retry_on_mode'
        )
      end

      def retry_context(retry_number:, resolved_retries:, budget_remaining:, elapsed_time:, sleep_total:, exception:)
        RetryContext.new(
          attempt: retry_number,
          retries: resolved_retries,
          metadata: @metadata,
          budget_remaining: budget_remaining,
          failure_fingerprint: failure_fingerprint(exception),
          elapsed_time: elapsed_time,
          sleep_total: sleep_total
        )
      end

      def failure_fingerprint(exception)
        return nil unless exception

        [exception.class.name, exception.message, exception.backtrace&.first].join(':')
      end

      def validate_callable!(callable, field:)
        return if callable.respond_to?(:call)

        raise ArgumentError, "#{field} must be callable"
      end

      def call_predicate(predicate, args)
        arity = predicate.respond_to?(:arity) ? predicate.arity : predicate.method(:call).arity
        return predicate.call if arity.zero?

        if arity.positive?
          predicate.call(*args.take(arity))
        else
          predicate.call(*args)
        end
      end

      def first_non_nil(*values)
        values.find { |value| !value.nil? }
      end

      def normalize_mode(value, allowed:, fallback:, field:)
        return fallback.to_sym if value.nil?

        mode = value.to_sym
        return mode if allowed.include?(mode)

        raise ArgumentError, "#{field} must be one of: #{allowed.join(', ')}"
      rescue NoMethodError
        raise ArgumentError, "#{field} must be one of: #{allowed.join(', ')}"
      end
    end
  end
end
