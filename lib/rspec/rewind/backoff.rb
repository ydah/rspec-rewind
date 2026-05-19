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

      def exponential(base:, factor: 2.0, max: nil, jitter: 0.0, rng: Kernel, min_factor: 0.0)
        base_value = normalize_numeric(base, 'base')
        factor_value = normalize_numeric(factor, 'factor')
        min_factor_value = normalize_numeric(min_factor, 'min_factor')
        jitter_value = normalize_numeric(jitter, 'jitter')
        max_value = max.nil? ? nil : normalize_numeric(max, 'max')
        raise ArgumentError, "factor must be >= #{min_factor_value}" if factor_value < min_factor_value

        lambda do |retry_number:, **_|
          exponent = [retry_number.to_i - 1, 0].max
          delay = base_value * (factor_value**exponent)
          delay = clamp(delay, max_value)

          next delay if jitter_value.zero?

          spread = delay * jitter_value
          min_delay = [delay - spread, 0.0].max
          max_delay = delay + spread
          clamp((random_value(rng) * (max_delay - min_delay)) + min_delay, max_value)
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

      def random_value(rng)
        raw =
          if rng.respond_to?(:rand)
            rng.rand
          elsif rng.respond_to?(:call)
            rng.call
          else
            raise ArgumentError, 'rng must respond to #rand or #call'
          end

        value = begin
          Float(raw)
        rescue TypeError, ArgumentError
          raise ArgumentError, 'rng must return a numeric value'
        end

        raise ArgumentError, 'rng must return a value between 0 and 1' unless value.between?(0.0, 1.0)

        value
      end
      private_class_method :random_value
    end
  end
end
