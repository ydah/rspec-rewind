# frozen_string_literal: true

module RSpec
  module Rewind
    module ConfigurationValidation
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

      def normalize_non_negative_float(value, field:)
        parsed = begin
          Float(value)
        rescue TypeError, ArgumentError
          raise ArgumentError, "#{field} must be a numeric value"
        end

        raise ArgumentError, "#{field} must be >= 0" if parsed.negative?

        parsed
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

      def normalize_symbol(value, allowed:, field:)
        symbol = value.to_sym
        return symbol if allowed.include?(symbol)

        raise ArgumentError, "#{field} must be one of #{allowed.join(', ')}"
      rescue NoMethodError
        raise ArgumentError, "#{field} must be one of #{allowed.join(', ')}"
      end

      def custom_budget?(value)
        return true if value.is_a?(RetryBudget)
        return false if value.nil? || value.is_a?(Numeric) || value.is_a?(String)

        value.respond_to?(:consume!) && value.respond_to?(:remaining)
      end
    end
  end
end
