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
        RetryDecision.new(
          exception: exception,
          example: @example,
          retry_on: effective_retry_on(retry_on),
          skip_retry_on: effective_skip_retry_on(skip_retry_on),
          retry_if: effective_retry_if(retry_if)
        ).retry?
      end

      private

      def effective_retry_on(explicit_retry_on)
        normalize_matchers(@configuration.retry_on, field: 'retry_on') +
          normalize_matchers(@metadata[:rewind_retry_on], field: 'rewind_retry_on') +
          normalize_matchers(explicit_retry_on, field: 'retry_on')
      end

      def effective_skip_retry_on(explicit_skip_retry_on)
        normalize_matchers(@configuration.skip_retry_on, field: 'skip_retry_on') +
          normalize_matchers(metadata_skip_retry_on, field: 'rewind_skip_retry_on') +
          normalize_matchers(explicit_skip_retry_on, field: 'skip_retry_on')
      end

      def effective_retry_if(explicit_retry_if)
        first_non_nil(explicit_retry_if, @metadata[:rewind_if], @configuration.retry_if)
      end

      def metadata_skip_retry_on
        @metadata[:rewind_skip_retry_on]
      end

      def first_non_nil(*values)
        values.find { |value| !value.nil? }
      end
    end
  end
end
