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
          value = attributes.fetch(field, nil)
          value = value.dup.freeze if value.is_a?(Array) || value.is_a?(Hash)
          instance_variable_set(:"@#{field}", value)
        end

        freeze
      end

      def to_h
        FIELDS.to_h do |field|
          [field, public_send(field)]
        end
      end
    end
  end
end
