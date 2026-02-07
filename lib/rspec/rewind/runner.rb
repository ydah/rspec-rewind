# frozen_string_literal: true

module RSpec
  module Rewind
    class Runner
      def initialize(example:, configuration:)
        @example = example
        @configuration = configuration
        @context = ExampleContext.new(example: example)
        @logger = RunnerLogger.new(configuration: configuration, warn_output: method(:warn))
      end

      def run(retries: nil, backoff: nil, wait: nil, retry_on: nil, skip_retry_on: nil, retry_if: nil)
        components.retry_loop.run(
          retries: retries,
          backoff: backoff,
          wait: wait,
          retry_on: retry_on,
          skip_retry_on: skip_retry_on,
          retry_if: retry_if
        )
      end

      private

      def components
        @components ||= RunnerComponents.new(
          example: @example,
          configuration: @configuration,
          context: @context,
          logger: @logger
        )
      end
    end
  end
end
