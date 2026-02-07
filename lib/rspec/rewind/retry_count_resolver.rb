# frozen_string_literal: true

module RSpec
  module Rewind
    class RetryCountResolver
      ENV_RETRIES_KEY = 'RSPEC_REWIND_RETRIES'

      def initialize(configuration:, metadata:)
        @configuration = configuration
        @metadata = metadata || {}
      end

      def resolve(explicit_retries:)
        env_retries = ENV.fetch(ENV_RETRIES_KEY, nil)
        return parse_non_negative_integer(env_retries, source: ENV_RETRIES_KEY) if env_retries

        configured = first_non_nil(
          normalize_retry_override(explicit_retries),
          normalize_retry_override(@metadata[:rewind]),
          @configuration.default_retries
        )

        parse_non_negative_integer(configured, source: 'retries')
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

      def first_non_nil(*values)
        values.find { |value| !value.nil? }
      end
    end
  end
end
