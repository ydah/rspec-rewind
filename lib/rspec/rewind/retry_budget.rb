# frozen_string_literal: true

require 'fileutils'

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

    class FileRetryBudget
      attr_reader :limit, :path

      def initialize(limit:, path:)
        @limit = normalize_limit(limit)
        @path = path
      end

      def consume!
        consume.allowed?
      end

      def consume
        with_locked_counter do |used, file|
          return decision(false, used) if used >= @limit

          used += 1
          write_used(file, used)
          decision(true, used)
        end
      end

      def used
        with_locked_counter { |current| current }
      end

      def remaining
        [@limit - used, 0].max
      end

      def unlimited?
        false
      end

      def reset!
        with_lock { |file| write_used(file, 0) }
      end

      private

      def with_locked_counter
        with_lock do |file|
          current = read_used(file)
          yield current, file
        end
      end

      def with_lock
        FileUtils.mkdir_p(File.dirname(@path))
        File.open(@path, File::RDWR | File::CREAT, 0o644) do |file|
          file.flock(File::LOCK_EX)
          yield file
        ensure
          file&.flock(File::LOCK_UN)
        end
      end

      def read_used(file)
        file.rewind
        text = file.read
        Integer(text.empty? ? '0' : text)
      end

      def write_used(file, value)
        file.rewind
        file.truncate(0)
        file.write(value.to_s)
        file.flush
      end

      def decision(allowed, used)
        BudgetDecision.new(
          allowed: allowed,
          limit: @limit,
          used: used,
          remaining: [@limit - used, 0].max
        )
      end

      def normalize_limit(limit)
        parsed = begin
          Integer(limit)
        rescue TypeError, ArgumentError
          raise ArgumentError, 'file retry budget must be a non-negative integer'
        end

        raise ArgumentError, 'file retry budget must be >= 0' if parsed.negative?

        parsed
      end
    end
  end
end
