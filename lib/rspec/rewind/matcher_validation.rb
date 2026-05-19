# frozen_string_literal: true

module RSpec
  module Rewind
    module MatcherValidation
      private

      def normalize_matchers(values, field:, strict_exception_matchers: false)
        matchers = Array(values).flatten.compact
        matchers.each do |matcher|
          validate_matcher!(
            matcher,
            field: field,
            strict_exception_matchers: strict_exception_matchers
          )
        end
        matchers
      end

      def validate_matcher!(matcher, field:, strict_exception_matchers:)
        if matcher.is_a?(Module)
          return unless strict_exception_matchers
          return if matcher.is_a?(Class) && matcher <= Exception

          raise ArgumentError,
                "#{field} Module entries must be Exception classes when strict matcher validation is enabled"
        end
        return if matcher.is_a?(Regexp) || matcher.respond_to?(:call)

        raise ArgumentError, "#{field} entries must be Module, Regexp, or callable"
      end
    end
  end
end
