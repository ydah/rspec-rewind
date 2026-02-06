# frozen_string_literal: true

module RSpec
  module Rewind
    class RetryBudget
      attr_reader :limit, :used

      def initialize(limit)
        @limit = normalize_limit(limit)
        @used = 0
        @mutex = Mutex.new
      end

      def consume!
        return true if unlimited?

        @mutex.synchronize do
          return false if @used >= @limit

          @used += 1
          true
        end
      end

      def remaining
        return Float::INFINITY if unlimited?

        [@limit - @used, 0].max
      end

      def unlimited?
        @limit.nil?
      end

      private

      def normalize_limit(limit)
        return nil if limit.nil?

        parsed = begin
          Integer(limit)
        rescue TypeError, ArgumentError
          raise ArgumentError, 'retry budget must be nil or a non-negative integer'
        end

        raise ArgumentError, 'retry budget must be >= 0' if parsed.negative?

        parsed
      end
    end
  end
end
