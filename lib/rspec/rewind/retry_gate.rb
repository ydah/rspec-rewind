# frozen_string_literal: true

module RSpec
  module Rewind
    class RetryGate
      def initialize(configuration:, retry_policy:, debug:)
        @configuration = configuration
        @retry_policy = retry_policy
        @debug = debug
      end

      def allow?(
        exception:,
        retry_number:,
        resolved_retries:,
        retry_on:,
        skip_retry_on:,
        retry_if:,
        example_id:
      )
        return false unless retry_number <= resolved_retries

        return false unless @retry_policy.retry_allowed?(
          exception: exception,
          retry_on: retry_on,
          skip_retry_on: skip_retry_on,
          retry_if: retry_if
        )

        return true if @configuration.retry_budget.consume!

        debug("retry budget exhausted for #{example_id}")
        false
      end

      private

      def debug(message)
        @debug.call(message)
      end
    end
  end
end
