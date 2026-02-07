# frozen_string_literal: true

module RSpec
  module Rewind
    class RetryDelayResolver
      def initialize(configuration:, metadata:, example:)
        @configuration = configuration
        @metadata = metadata || {}
        @example = example
      end

      def resolve(retry_number:, backoff:, wait:, exception:)
        explicit_wait = first_non_nil(wait, @metadata[:rewind_wait])
        return normalize_delay(explicit_wait) if explicit_wait

        strategy = first_non_nil(backoff, @metadata[:rewind_backoff], @configuration.backoff)
        return normalize_delay(strategy) if strategy.is_a?(Numeric)

        return 0.0 unless strategy.respond_to?(:call)

        raw = strategy.call(
          retry_number: retry_number,
          example: @example,
          exception: exception
        )

        normalize_delay(raw)
      end

      private

      def normalize_delay(value)
        parsed = begin
          Float(value)
        rescue TypeError, ArgumentError
          raise ArgumentError, 'delay must be numeric'
        end

        raise ArgumentError, 'delay must be >= 0' if parsed.negative?

        parsed
      end

      def first_non_nil(*values)
        values.find { |value| !value.nil? }
      end
    end
  end
end
