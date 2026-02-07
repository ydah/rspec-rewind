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
          exception, duration, raised = run_attempt

          if exception.nil?
            publish_flaky_event(attempt: attempt, retries: resolved_retries, duration: duration) if attempt > 1
            return
          end

          retry_number = attempt
          unless can_retry_exception?(exception: exception, raised: raised, retry_number: retry_number,
                                      resolved_retries: resolved_retries, retry_on: retry_on,
                                      skip_retry_on: skip_retry_on, retry_if: retry_if)
            return
          end

          sleep_seconds = retry_delay_resolver.resolve(
            retry_number: retry_number,
            backoff: backoff,
            wait: wait,
            exception: exception
          )

          event = build_event(
            status: :retrying,
            retry_reason: :exception,
            attempt: retry_number,
            retries: resolved_retries,
            duration: duration,
            sleep_seconds: sleep_seconds,
            exception: exception
          )

          notifier.notify_retry(event)
          notifier.show_failure_message(exception) if @configuration.display_retry_failure_messages
          clear_for_retry
          sleep_if_needed(sleep_seconds)

          attempt += 1
        end
      end

      private

      def run_attempt
        started_at = monotonic_time

        begin
          @example.run
          duration = monotonic_time - started_at
          [current_exception, duration, false]
        rescue Exception => e # rubocop:disable Lint/RescueException
          raise if fatal_exception?(e)

          duration = monotonic_time - started_at
          [e, duration, true]
        end
      end

      def retry_allowed?(exception:, retry_on:, skip_retry_on:, retry_if:)
        retry_policy.retry_allowed?(
          exception: exception,
          retry_on: retry_on,
          skip_retry_on: skip_retry_on,
          retry_if: retry_if
        )
      end

      def can_retry_exception?(
        exception:,
        raised:,
        retry_number:,
        resolved_retries:,
        retry_on:,
        skip_retry_on:,
        retry_if:
      )
        unless retry_number <= resolved_retries
          raise exception if raised

          return false
        end

        unless retry_allowed?(exception: exception, retry_on: retry_on, skip_retry_on: skip_retry_on,
                              retry_if: retry_if)
          raise exception if raised

          return false
        end

        unless @configuration.retry_budget.consume!
          debug("retry budget exhausted for #{example_id}")
          raise exception if raised

          return false
        end

        true
      end

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

      def clear_for_retry
        state_resetter.reset(example_source)
      end

      def sleep_if_needed(seconds)
        return unless seconds.positive?

        Kernel.sleep(seconds)
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

      def monotonic_time
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end

      def example_source
        return @example.example if @example.respond_to?(:example) && @example.example

        @example
      end

      def current_exception
        source = example_source
        source.respond_to?(:exception) ? source.exception : nil
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

      def fatal_exception?(exception)
        exception.is_a?(NoMemoryError) ||
          exception.is_a?(ScriptError) ||
          exception.is_a?(SignalException) ||
          exception.is_a?(SystemExit) ||
          exception.is_a?(SecurityError)
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
