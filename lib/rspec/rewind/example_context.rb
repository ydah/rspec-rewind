# frozen_string_literal: true

module RSpec
  module Rewind
    class ExampleContext
      def initialize(example:)
        @example = example
      end

      def source
        return @example.example if @example.respond_to?(:example) && @example.example

        @example
      end

      def metadata
        return {} unless source.respond_to?(:metadata)

        source.metadata || {}
      end

      def id
        source.respond_to?(:id) ? source.id : 'unknown'
      end
    end
  end
end
