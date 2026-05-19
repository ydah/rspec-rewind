# frozen_string_literal: true

module RSpec
  module Rewind
    class RetryDelayResolver
      def initialize(configuration:, metadata:, example:, warn: ->(_message) {})
        @configuration = configuration
        @metadata = metadata || {}
        @example = example
        @warn = warn
        @delay_conflict_warned = false
      end

      DelayContext = Struct.new(
        :retry_number,
        :resolved_retries,
        :metadata,
        :previous_sleep_seconds,
        :failure_fingerprint,
        keyword_init: true
      )

      def resolve(
        retry_number:,
        backoff:,
        wait:,
        exception:,
        resolved_retries: nil,
        previous_sleep_seconds: 0.0,
        failure_fingerprint: nil
      )
        explicit_wait = first_non_nil(wait, @metadata[:rewind_wait])
        warn_delay_conflict(wait: wait, backoff: backoff)
        return normalize_delay(explicit_wait) if explicit_wait

        strategy = first_non_nil(backoff, @metadata[:rewind_backoff], @configuration.backoff)
        return normalize_delay(strategy) if strategy.is_a?(Numeric)

        raise ArgumentError, 'backoff must be a non-negative numeric value or callable' unless strategy.respond_to?(:call)

        args = {
          retry_number: retry_number,
          example: @example,
          exception: exception
        }
        args[:context] = DelayContext.new(
          retry_number: retry_number,
          resolved_retries: resolved_retries,
          metadata: @metadata,
          previous_sleep_seconds: previous_sleep_seconds,
          failure_fingerprint: failure_fingerprint
        ) if accepts_keyword?(strategy, :context)

        raw = strategy.call(**args)

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

      def warn_delay_conflict(wait:, backoff:)
        return unless @configuration.warn_on_delay_conflict
        return if @delay_conflict_warned
        return unless !first_non_nil(wait, @metadata[:rewind_wait]).nil? &&
                      !first_non_nil(backoff, @metadata[:rewind_backoff]).nil?

        @delay_conflict_warned = true
        @warn.call('[rspec-rewind] wait and backoff are both configured; wait takes precedence')
      end

      def accepts_keyword?(callable, keyword)
        parameters = callable.respond_to?(:parameters) ? callable.parameters : callable.method(:call).parameters
        parameters.any? do |type, name|
          type == :keyrest || ((type == :key || type == :keyreq) && name == keyword)
        end
      end
    end
  end
end
