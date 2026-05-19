# frozen_string_literal: true

module RSpec
  module Rewind
    class Runner
      def initialize(example:, configuration:, component_factory: RunnerComponentFactory.new)
        @example = example
        @configuration = configuration.snapshot
        @component_factory = component_factory
        @context = ExampleContext.new(example: example)
        @logger = RunnerLogger.new(configuration: @configuration, warn_output: method(:warn))
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
        @components ||= @component_factory.build(
          example: @example,
          configuration: @configuration,
          context: @context,
          logger: @logger
        )
      end
    end
  end
end
