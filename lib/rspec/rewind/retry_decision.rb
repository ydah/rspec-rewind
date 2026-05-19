# frozen_string_literal: true

module RSpec
  module Rewind
    RetryDecisionResult = Struct.new(
      :allowed,
      :reason,
      :matched_retry_on,
      :matched_skip_retry_on,
      :matcher_error,
      keyword_init: true
    ) do
      def allowed?
        allowed
      end
    end

    RetryContext = Struct.new(
      :attempt,
      :retries,
      :metadata,
      :budget_remaining,
      :failure_fingerprint,
      keyword_init: true
    )

    class RetryDecision
      def initialize(
        exception:,
        example:,
        retry_on:,
        skip_retry_on:,
        retry_if:,
        retry_on_default: :all,
        context: nil,
        strict_callable_arity: false
      )
        @exception = exception
        @example = example
        @retry_on = normalize_matchers(retry_on)
        @skip_retry_on = normalize_matchers(skip_retry_on)
        @retry_if = retry_if
        @retry_on_default = retry_on_default
        @context = context
        @strict_callable_arity = strict_callable_arity
      end

      def retry?
        decision.allowed?
      end

      def decision
        return rejected(:no_exception) unless @exception

        skip_match = find_match(@skip_retry_on)
        if skip_match.matched?
          return rejected(
            :skip_retry_on_matched,
            matched_skip_retry_on: skip_match.description,
            matcher_error: skip_match.error
          )
        end

        retry_match = nil
        if @retry_on.any?
          retry_match = find_match(@retry_on)
          unless retry_match.matched?
            return rejected(
              :retry_on_not_matched,
              matcher_error: retry_match.error
            )
          end
        elsif !retry_on_default_allowed?
          return rejected(:retry_on_default_rejected)
        end

        if @retry_if && !call_with_context(@retry_if)
          return rejected(
            :predicate_rejected,
            matched_retry_on: retry_match&.description
          )
        end

        allowed(matched_retry_on: retry_match&.description)
      end

      MatchResult = Struct.new(:matched, :description, :error, keyword_init: true) do
        def matched?
          matched
        end
      end

      private

      def find_match(matchers)
        last_error = nil

        matchers.each do |matcher|
          result = match(matcher)
          return result if result.matched?

          last_error ||= result.error
        end

        MatchResult.new(matched: false, error: last_error)
      end

      def match(matcher)
        matched =
          case matcher
          when Module
            @exception.is_a?(matcher)
          when Regexp
            matcher.match?(@exception.message.to_s)
          else
            matcher.respond_to?(:call) && !call_with_context(matcher).nil?
          end

        MatchResult.new(matched: matched, description: matcher_description(matcher))
      rescue StandardError => e
        MatchResult.new(matched: false, description: matcher_description(matcher), error: "#{e.class}: #{e.message}")
      end

      def retry_on_default_allowed?
        return @exception.is_a?(StandardError) if @retry_on_default == :standard_errors
        return false if @retry_on_default == :none

        true
      end

      def call_with_context(callable)
        arity = callable_arity(callable)
        return callable.call if arity.zero?

        required = arity.negative? ? (-arity - 1) : arity
        args = [@exception, @example, @context]
        if @strict_callable_arity && arity.positive? && required > args.length
          raise ArgumentError, "callable accepts #{required} required arguments; maximum supported is #{args.length}"
        end

        args << nil while args.length < required

        if arity.positive?
          callable.call(*args.take(arity))
        else
          callable.call(*args)
        end
      end

      def callable_arity(callable)
        return callable.arity if callable.respond_to?(:arity)

        callable.method(:call).arity
      end

      def normalize_matchers(values)
        Array(values).flatten.compact
      end

      def allowed(**attributes)
        RetryDecisionResult.new(allowed: true, reason: :allowed, **attributes)
      end

      def rejected(reason, **attributes)
        RetryDecisionResult.new(allowed: false, reason: reason, **attributes)
      end

      def matcher_description(matcher)
        return matcher.description if matcher.respond_to?(:description)
        return matcher.name if matcher.respond_to?(:name) && matcher.name

        matcher.inspect
      end
    end
  end
end
