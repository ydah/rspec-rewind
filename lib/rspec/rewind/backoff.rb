# frozen_string_literal: true

module RSpec
  module Rewind
    module Backoff
      module_function

      def fixed(seconds)
        value = normalize_numeric(seconds, 'seconds')
        ->(**_) { value }
      end

      def linear(step:, max: nil)
        step_value = normalize_numeric(step, 'step')
        max_value = max.nil? ? nil : normalize_numeric(max, 'max')

        lambda do |retry_number:, **_|
          delay = step_value * retry_number.to_i
          clamp(delay, max_value)
        end
      end

      def exponential(base:, factor: 2.0, max: nil, jitter: 0.0)
        base_value = normalize_numeric(base, 'base')
        factor_value = normalize_numeric(factor, 'factor')
        jitter_value = normalize_numeric(jitter, 'jitter')
        max_value = max.nil? ? nil : normalize_numeric(max, 'max')

        lambda do |retry_number:, **_|
          exponent = [retry_number.to_i - 1, 0].max
          delay = base_value * (factor_value**exponent)
          delay = clamp(delay, max_value)

          next delay if jitter_value.zero?

          spread = delay * jitter_value
          min_delay = [delay - spread, 0.0].max
          max_delay = delay + spread
          (Kernel.rand * (max_delay - min_delay)) + min_delay
        end
      end

      def clamp(value, max)
        return value unless max

        [value, max].min
      end
      private_class_method :clamp

      def normalize_numeric(value, name)
        number = begin
          Float(value)
        rescue TypeError, ArgumentError
          raise ArgumentError, "#{name} must be a numeric value"
        end

        raise ArgumentError, "#{name} must be >= 0" if number.negative?

        number
      end
      private_class_method :normalize_numeric
    end
  end
end
