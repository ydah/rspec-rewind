# frozen_string_literal: true

module RSpec
  module Rewind
    EVENT_SCHEMA_VERSION = 1

    class Event
      FIELDS = %i[
        schema_version
        status
        retry_reason
        decision_reason
        example_id
        description
        location
        attempt
        retries
        max_attempts
        exception_class
        exception_message
        exception_backtrace_top
        failure_fingerprint
        duration
        total_duration
        attempt_durations
        first_failure_duration
        sleep_seconds
        scheduled_sleep_seconds
        actual_sleep_seconds
        sleep_total
        timestamp
        budget_limit
        budget_used
        budget_remaining
        matched_retry_on
        matched_skip_retry_on
        matcher_error
        metadata
      ].freeze

      attr_reader(*FIELDS)

      def initialize(**attributes)
        FIELDS.each do |field|
          instance_variable_set(:"@#{field}", immutable_value(attributes.fetch(field, nil)))
        end

        freeze
      end

      def to_h
        FIELDS.to_h do |field|
          [field, public_send(field)]
        end
      end

      private

      def immutable_value(value)
        case value
        when Array
          value.map { |item| immutable_value(item) }.freeze
        when Hash
          value.each_with_object({}) do |(key, item), copy|
            copy[immutable_value(key)] = immutable_value(item)
          end.freeze
        when String
          value.dup.freeze
        else
          value
        end
      end
    end
  end
end
