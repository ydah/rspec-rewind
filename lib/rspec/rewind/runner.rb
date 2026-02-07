# frozen_string_literal: true

module RSpec
  module Rewind
    class Runner
      def initialize(example:, configuration:)
        @example = example
        @configuration = configuration
      end

      def run(retries: nil, backoff: nil, wait: nil, retry_on: nil, skip_retry_on: nil, retry_if: nil)
        resolved_retries = retry_count_resolver.resolve(explicit_retries: retries)
        return @example.run if resolved_retries <= 0

        total_attempts = resolved_retries + 1
        attempt = 1

        while attempt <= total_attempts
          exception, duration, raised = attempt_runner.run(run_target: @example, exception_source: example_source)

          if exception.nil?
            publish_flaky_event(attempt: attempt, retries: resolved_retries, duration: duration) if attempt > 1
            return
          end

          retry_number = attempt
          unless retry_gate.allow?(exception: exception, retry_number: retry_number, resolved_retries: resolved_retries,
                                   retry_on: retry_on, skip_retry_on: skip_retry_on, retry_if: retry_if,
                                   example_id: example_id)
            raise exception if raised

            return
          end

          retry_transition.perform(
            retry_number: retry_number,
            resolved_retries: resolved_retries,
            duration: duration,
            exception: exception,
            backoff: backoff,
            wait: wait,
            example_source: example_source
          )

          attempt += 1
        end
      end

      private

      def publish_flaky_event(attempt:, retries:, duration:)
        event = build_event(
          status: :flaky,
          retry_reason: nil,
          attempt: attempt,
          retries: retries,
          duration: duration,
          sleep_seconds: 0.0,
          exception: nil
        )

        notifier.publish_flaky(event)
      end

      def build_event(status:, retry_reason:, attempt:, retries:, duration:, sleep_seconds:, exception:)
        event_builder.build(
          status: status,
          retry_reason: retry_reason,
          attempt: attempt,
          retries: retries,
          duration: duration,
          sleep_seconds: sleep_seconds,
          exception: exception
        )
      end

      def example_source
        return @example.example if @example.respond_to?(:example) && @example.example

        @example
      end

      def example_metadata
        source = example_source
        return {} unless source.respond_to?(:metadata)

        source.metadata || {}
      end

      def example_id
        source = example_source
        source.respond_to?(:id) ? source.id : 'unknown'
      end

      def event_builder
        @event_builder ||= RetryEventBuilder.new(example_source: example_source)
      end

      def notifier
        @notifier ||= RetryNotifier.new(
          configuration: @configuration,
          debug: method(:debug),
          reporter_message: method(:reporter_message)
        )
      end

      def state_resetter
        @state_resetter ||= ExampleStateResetter.new(configuration: @configuration)
      end

      def retry_policy
        @retry_policy ||= RetryPolicy.new(
          example: @example,
          configuration: @configuration,
          metadata: example_metadata
        )
      end

      def retry_gate
        @retry_gate ||= RetryGate.new(
          configuration: @configuration,
          retry_policy: retry_policy,
          debug: method(:debug)
        )
      end

      def attempt_runner
        @attempt_runner ||= AttemptRunner.new
      end

      def retry_transition
        @retry_transition ||= RetryTransition.new(
          configuration: @configuration,
          retry_delay_resolver: retry_delay_resolver,
          event_builder: event_builder,
          notifier: notifier,
          state_resetter: state_resetter,
          sleep: Kernel.method(:sleep)
        )
      end

      def retry_count_resolver
        @retry_count_resolver ||= RetryCountResolver.new(
          configuration: @configuration,
          metadata: example_metadata
        )
      end

      def retry_delay_resolver
        @retry_delay_resolver ||= RetryDelayResolver.new(
          configuration: @configuration,
          metadata: example_metadata,
          example: @example
        )
      end

      def reporter_message(message)
        if defined?(::RSpec) && ::RSpec.respond_to?(:configuration)
          reporter = ::RSpec.configuration.reporter
          reporter&.message(message)
        end
      rescue StandardError
        warn(message)
      end

      def debug(message)
        return unless @configuration.verbose

        reporter_message("[rspec-rewind] #{message}")
      end
    end
  end
end
