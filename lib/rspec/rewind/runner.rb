# frozen_string_literal: true

module RSpec
  module Rewind
    class Runner
      ENV_RETRIES_KEY = 'RSPEC_REWIND_RETRIES'

      def initialize(example:, configuration:)
        @example = example
        @configuration = configuration
      end

      def run(retries: nil, backoff: nil, wait: nil, retry_on: nil, skip_retry_on: nil, retry_if: nil)
        resolved_retries = resolve_retries(retries)
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
          unless retry_number <= resolved_retries
            raise exception if raised

            return
          end

          unless retry_allowed?(exception: exception, retry_on: retry_on, skip_retry_on: skip_retry_on,
                                retry_if: retry_if)
            raise exception if raised

            return
          end

          unless @configuration.retry_budget.consume!
            debug("retry budget exhausted for #{example_id}")
            raise exception if raised

            return
          end

          sleep_seconds = resolve_sleep_seconds(
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

      def resolve_retries(explicit_retries)
        env_retries = ENV.fetch(ENV_RETRIES_KEY, nil)
        return parse_non_negative_integer(env_retries, source: ENV_RETRIES_KEY) if env_retries

        metadata = example_metadata
        configured = first_non_nil(
          normalize_retry_override(explicit_retries),
          normalize_retry_override(metadata[:rewind]),
          normalize_retry_override(metadata[:retry]),
          @configuration.default_retries
        )

        parse_non_negative_integer(configured, source: 'retries')
      end

      def normalize_retry_override(value)
        return nil if value.nil? || value == true
        return 0 if value == false

        value
      end

      def retry_allowed?(exception:, retry_on:, skip_retry_on:, retry_if:)
        metadata = example_metadata

        effective_retry_on = normalize_matchers(@configuration.retry_on) +
                             normalize_matchers(metadata[:rewind_retry_on]) +
                             normalize_matchers(retry_on)

        metadata_skip_retry_on = first_non_nil(
          metadata[:rewind_skip_retry_on],
          metadata[:rewind_skip_on]
        )

        effective_skip_retry_on = normalize_matchers(@configuration.skip_retry_on) +
                                  normalize_matchers(metadata_skip_retry_on) +
                                  normalize_matchers(skip_retry_on)

        effective_retry_if = first_non_nil(retry_if, metadata[:rewind_if], @configuration.retry_if)

        RetryDecision.new(
          exception: exception,
          example: @example,
          retry_on: effective_retry_on,
          skip_retry_on: effective_skip_retry_on,
          retry_if: effective_retry_if
        ).retry?
      end

      def resolve_sleep_seconds(retry_number:, backoff:, wait:, exception:)
        metadata = example_metadata
        explicit_wait = first_non_nil(wait, metadata[:rewind_wait])

        return normalize_delay(explicit_wait) if explicit_wait

        strategy = first_non_nil(backoff, metadata[:rewind_backoff], @configuration.backoff)
        return normalize_delay(strategy) if strategy.is_a?(Numeric)

        return 0.0 unless strategy.respond_to?(:call)

        raw = strategy.call(
          retry_number: retry_number,
          example: @example,
          exception: exception
        )

        normalize_delay(raw)
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

      def parse_non_negative_integer(value, source:)
        return 0 if value.nil?

        parsed = begin
          Integer(value)
        rescue TypeError, ArgumentError
          raise ArgumentError, "#{source} must be a non-negative integer"
        end

        raise ArgumentError, "#{source} must be >= 0" if parsed.negative?

        parsed
      end

      def normalize_delay(value)
        parsed = begin
          Float(value)
        rescue TypeError, ArgumentError
          raise ArgumentError, 'delay must be numeric'
        end

        raise ArgumentError, 'delay must be >= 0' if parsed.negative?

        parsed
      end

      def normalize_matchers(values)
        Array(values).flatten.compact
      end

      def monotonic_time
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end

      def first_non_nil(*values)
        values.find { |value| !value.nil? }
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
