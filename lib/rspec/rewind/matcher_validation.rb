# frozen_string_literal: true

module RSpec
  module Rewind
    module MatcherValidation
      private

      def normalize_matchers(values, field:)
        matchers = Array(values).flatten.compact
        matchers.each { |matcher| validate_matcher!(matcher, field: field) }
        matchers
      end

      def validate_matcher!(matcher, field:)
        return if matcher.is_a?(Module) || matcher.is_a?(Regexp) || matcher.respond_to?(:call)

        raise ArgumentError, "#{field} entries must be Module, Regexp, or callable"
      end
    end
  end
end
