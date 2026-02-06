# frozen_string_literal: true

module RSpec
  module Rewind
    EVENT_SCHEMA_VERSION = 1

    Event = Struct.new(
      :schema_version,
      :status,
      :retry_reason,
      :example_id,
      :description,
      :location,
      :attempt,
      :retries,
      :exception_class,
      :exception_message,
      :duration,
      :sleep_seconds,
      :timestamp,
      keyword_init: true
    )
  end
end
