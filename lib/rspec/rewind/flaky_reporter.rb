# frozen_string_literal: true

require "json"
require "fileutils"

module RSpec
  module Rewind
    class FlakyReporter
      class << self
        def null
          @null ||= NullReporter.new
        end

        def jsonl(path)
          JsonlReporter.new(path)
        end
      end

      class NullReporter
        def record(_event); end
      end

      class JsonlReporter
        def initialize(path)
          @path = path
          @mutex = Mutex.new
        end

        def record(event)
          payload = {
            status: event.status,
            example_id: event.example_id,
            description: event.description,
            location: event.location,
            attempt: event.attempt,
            retries: event.retries,
            exception_class: event.exception_class,
            exception_message: event.exception_message,
            duration: event.duration,
            sleep_seconds: event.sleep_seconds,
            timestamp: event.timestamp
          }

          @mutex.synchronize do
            FileUtils.mkdir_p(File.dirname(@path))
            File.open(@path, "a") { |file| file.puts(JSON.generate(payload)) }
          end
        end
      end
    end
  end
end
