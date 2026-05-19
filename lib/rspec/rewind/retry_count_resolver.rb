# frozen_string_literal: true

module RSpec
  module Rewind
    class RetryCountResolver
      ENV_RETRIES_KEY = 'RSPEC_REWIND_RETRIES'
      ENV_DISABLE_KEY = 'RSPEC_REWIND_DISABLE'

      def initialize(configuration:, metadata:)
        @configuration = configuration
        @metadata = metadata || {}
      end

      def resolve(explicit_retries:)
        return 0 if normalize_retry_override(explicit_retries) == 0 # rubocop:disable Style/NumericPredicate
        return 0 if env_disabled?

        env_retries = env_retries_value
        return capped(parse_non_negative_integer(env_retries, source: ENV_RETRIES_KEY)) if env_retries

        configured = first_non_nil(
          normalize_retry_override(explicit_retries),
          normalize_retry_override(@metadata[:rewind]),
          @configuration.default_retries
        )

        capped(parse_non_negative_integer(configured, source: 'retries'))
      end

      private

      def normalize_retry_override(value)
        return nil if value.nil? || value == true
        return 0 if value == false

        value
      end

      def parse_non_negative_integer(value, source:)
        return 0 if value.nil?

        parsed = begin
          Integer(value)
        rescue TypeError, ArgumentError
          raise ArgumentError, "#{source} must be a non-negative integer"
        end

        raise ArgumentError, "#{source} must be >= 0" if parsed.negative?

        parsed
      end

      def env_retries_value
        value = ENV.fetch(ENV_RETRIES_KEY, nil)
        return nil if value.nil? || value.to_s.empty?

        value
      end

      def env_disabled?
        value = ENV.fetch(ENV_DISABLE_KEY, nil)
        %w[1 true yes on].include?(value.to_s.downcase)
      end

      def capped(value)
        max_retries = @configuration.max_retries
        return value if max_retries.nil? || value <= max_retries

        raise ArgumentError, "retries must be <= #{max_retries}"
      end

      def first_non_nil(*values)
        values.find { |value| !value.nil? }
      end
    end
  end
end
