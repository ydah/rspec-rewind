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

        if @retry_on.any? && !matches_any?(@retry_on)
          return false
        end

        return true unless @retry_if

        !!@retry_if.call(@exception, @example)
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
          matcher.respond_to?(:call) && !!matcher.call(@exception)
        end
      rescue StandardError
        false
      end

      def normalize_matchers(values)
        Array(values).flatten.compact
      end
    end
  end
end
