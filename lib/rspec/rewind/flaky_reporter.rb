# frozen_string_literal: true

require 'json'
require 'fileutils'

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
        attr_reader :path

        def initialize(path)
          @path = path
          @mutex = Mutex.new
        end

        def record(event)
          payload = event.respond_to?(:to_h) ? event.to_h : {}

          @mutex.synchronize do
            FileUtils.mkdir_p(File.dirname(@path))
            File.open(@path, 'a') do |file|
              file.flock(File::LOCK_EX)
              file.puts(JSON.generate(payload))
              file.flush
            ensure
              file&.flock(File::LOCK_UN)
            end
          end
        end

        def flush; end

        def close; end
      end
    end
  end
end
