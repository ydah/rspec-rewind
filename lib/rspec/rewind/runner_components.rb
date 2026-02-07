# frozen_string_literal: true

module RSpec
  module Rewind
    class RunnerComponents
      attr_reader :retry_count_resolver,
                  :attempt_runner,
                  :retry_gate,
                  :retry_transition,
                  :flaky_transition

      def initialize(example:, configuration:, context:, logger:)
        event_builder = RetryEventBuilder.new(example_source: context.source)
        notifier = RetryNotifier.new(
          configuration: configuration,
          debug: logger.method(:debug),
          reporter_message: logger.method(:reporter_message)
        )
        state_resetter = ExampleStateResetter.new(configuration: configuration)
        retry_policy = RetryPolicy.new(
          example: example,
          configuration: configuration,
          metadata: context.metadata
        )
        retry_delay_resolver = RetryDelayResolver.new(
          configuration: configuration,
          metadata: context.metadata,
          example: example
        )

        @retry_count_resolver = RetryCountResolver.new(
          configuration: configuration,
          metadata: context.metadata
        )
        @attempt_runner = AttemptRunner.new
        @retry_gate = RetryGate.new(
          configuration: configuration,
          retry_policy: retry_policy,
          debug: logger.method(:debug)
        )
        @retry_transition = RetryTransition.new(
          configuration: configuration,
          retry_delay_resolver: retry_delay_resolver,
          event_builder: event_builder,
          notifier: notifier,
          state_resetter: state_resetter,
          sleep: Kernel.method(:sleep)
        )
        @flaky_transition = FlakyTransition.new(
          event_builder: event_builder,
          notifier: notifier
        )
      end
    end
  end
end
