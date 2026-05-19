# frozen_string_literal: true

module RSpec
  module Rewind
    BudgetDecision = Struct.new(
      :allowed,
      :limit,
      :used,
      :remaining,
      keyword_init: true
    ) do
      def allowed?
        allowed
      end
    end

    class RetryBudget
      attr_reader :limit, :used

      def initialize(limit)
        @limit = normalize_limit(limit)
        @used = 0
        @mutex = Mutex.new
      end

      def consume!
        consume.allowed?
      end

      def consume
        return decision(true) if unlimited?

        @mutex.synchronize do
          return decision(false) if @used >= @limit

          @used += 1
          decision(true)
        end
      end

      def remaining
        return Float::INFINITY if unlimited?

        [@limit - @used, 0].max
      end

      def unlimited?
        @limit.nil?
      end

      def reset!
        @mutex.synchronize { @used = 0 }
      end

      private

      def decision(allowed)
        BudgetDecision.new(
          allowed: allowed,
          limit: @limit,
          used: @used,
          remaining: remaining
        )
      end

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
