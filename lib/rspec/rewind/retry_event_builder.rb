# frozen_string_literal: true

module RSpec
  module Rewind
    class RetryEventBuilder
      def initialize(example_source:)
        @example_source = example_source
      end

      def build(status:, retry_reason:, attempt:, retries:, duration:, sleep_seconds:, exception:)
        Event.new(
          schema_version: EVENT_SCHEMA_VERSION,
          status: status,
          retry_reason: retry_reason,
          example_id: @example_source.id,
          description: @example_source.full_description,
          location: @example_source.location,
          attempt: attempt,
          retries: retries,
          exception_class: exception&.class&.name,
          exception_message: exception&.message,
          duration: duration,
          sleep_seconds: sleep_seconds,
          timestamp: Time.now.utc.iso8601
        )
      end
    end
  end
end
