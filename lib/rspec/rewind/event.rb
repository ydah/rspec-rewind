# frozen_string_literal: true

module RSpec
  module Rewind
    Event = Struct.new(
      :status,
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
