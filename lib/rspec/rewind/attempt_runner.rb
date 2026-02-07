# frozen_string_literal: true

module RSpec
  module Rewind
    class AttemptRunner
      FATAL_EXCEPTIONS = [
        NoMemoryError,
        ScriptError,
        SignalException,
        SystemExit,
        SecurityError
      ].freeze

      def run(run_target:, exception_source:)
        started_at = monotonic_time

        begin
          run_target.run
          duration = monotonic_time - started_at
          [current_exception(exception_source), duration, false]
        rescue Exception => e
          raise if fatal_exception?(e)

          duration = monotonic_time - started_at
          [e, duration, true]
        end
      end

      private

      def monotonic_time
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end

      def current_exception(exception_source)
        return nil unless exception_source.respond_to?(:exception)

        exception_source.exception
      end

      def fatal_exception?(exception)
        FATAL_EXCEPTIONS.any? { |klass| exception.is_a?(klass) }
      end
    end
  end
end
