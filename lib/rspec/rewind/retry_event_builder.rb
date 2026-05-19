# frozen_string_literal: true

module RSpec
  module Rewind
    class RetryEventBuilder
      def initialize(example_source:, metadata_keys: [])
        @example_source = example_source
        @metadata_keys = Array(metadata_keys).map(&:to_sym)
      end

      def build(
        status:,
        retry_reason:,
        attempt:,
        retries:,
        duration:,
        sleep_seconds:,
        exception:,
        decision_reason: nil,
        total_duration: nil,
        attempt_durations: nil,
        first_failure_duration: nil,
        scheduled_sleep_seconds: sleep_seconds,
        actual_sleep_seconds: nil,
        sleep_total: nil,
        budget_decision: nil,
        matched_retry_on: nil,
        matched_skip_retry_on: nil,
        matcher_error: nil
      )
        Event.new(
          schema_version: EVENT_SCHEMA_VERSION,
          status: status,
          retry_reason: retry_reason,
          decision_reason: decision_reason,
          example_id: safe_read(:id, 'unknown'),
          description: safe_read(:full_description, 'unknown'),
          location: safe_read(:location, 'unknown'),
          attempt: attempt,
          retries: retries,
          max_attempts: retries.to_i + 1,
          exception_class: exception&.class&.name,
          exception_message: exception&.message,
          exception_backtrace_top: exception&.backtrace&.first,
          failure_fingerprint: failure_fingerprint(exception),
          duration: duration,
          total_duration: total_duration,
          attempt_durations: attempt_durations,
          first_failure_duration: first_failure_duration,
          sleep_seconds: sleep_seconds,
          scheduled_sleep_seconds: scheduled_sleep_seconds,
          actual_sleep_seconds: actual_sleep_seconds,
          sleep_total: sleep_total,
          timestamp: Time.now.utc.iso8601,
          budget_limit: read_decision_value(budget_decision, :limit),
          budget_used: read_decision_value(budget_decision, :used),
          budget_remaining: read_decision_value(budget_decision, :remaining),
          matched_retry_on: matched_retry_on,
          matched_skip_retry_on: matched_skip_retry_on,
          matcher_error: matcher_error,
          metadata: filtered_metadata
        )
      end

      private

      def safe_read(method_name, fallback)
        return fallback unless @example_source.respond_to?(method_name)

        value = @example_source.public_send(method_name)
        value.nil? ? fallback : value
      rescue StandardError
        fallback
      end

      def failure_fingerprint(exception)
        return nil unless exception

        [
          exception.class.name,
          exception.message,
          exception.backtrace&.first
        ].join(':')
      end

      def filtered_metadata
        return nil if @metadata_keys.empty?
        return {} unless @example_source.respond_to?(:metadata)

        metadata = @example_source.metadata || {}
        @metadata_keys.each_with_object({}) do |key, selected|
          selected[key] = metadata[key] if metadata.key?(key)
        end
      rescue StandardError
        {}
      end

      def read_decision_value(decision, field)
        return nil unless decision
        return decision.public_send(field) if decision.respond_to?(field)

        nil
      end
    end
  end
end
