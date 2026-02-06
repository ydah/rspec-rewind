# frozen_string_literal: true

module RSpec
  module Rewind
    class RetryDecision
      def initialize(exception:, example:, retry_on:, skip_retry_on:, retry_if:)
        @exception = exception
        @example = example
        @retry_on = normalize_matchers(retry_on)
        @skip_retry_on = normalize_matchers(skip_retry_on)
        @retry_if = retry_if
      end

      def retry?
        return false unless @exception
        return false if matches_any?(@skip_retry_on)

        return false if @retry_on.any? && !matches_any?(@retry_on)

        return true unless @retry_if

        !!call_with_context(@retry_if)
      end

      private

      def matches_any?(matchers)
        matchers.any? { |matcher| match?(matcher) }
      end

      def match?(matcher)
        case matcher
        when Module
          @exception.is_a?(matcher)
        when Regexp
          matcher.match?(@exception.message.to_s)
        else
          matcher.respond_to?(:call) && !!call_with_context(matcher)
        end
      rescue StandardError
        false
      end

      def call_with_context(callable)
        arity = callable_arity(callable)
        return callable.call if arity.zero?

        required = arity.negative? ? (-arity - 1) : arity
        args = [@exception, @example]
        args << nil while args.length < required

        if arity.positive?
          callable.call(*args.take(arity))
        else
          callable.call(*args)
        end
      end

      def callable_arity(callable)
        return callable.arity if callable.respond_to?(:arity)

        callable.method(:call).arity
      end

      def normalize_matchers(values)
        Array(values).flatten.compact
      end
    end
  end
end
