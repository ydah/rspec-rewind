# frozen_string_literal: true

module RSpec
  module Rewind
    class ExampleStateResetter
      attr_reader :last_exception

      def initialize(configuration:, adapter: RSpecAdapter.new)
        @configuration = configuration
        @adapter = adapter
        @last_exception = nil
      end

      def reset(example_source)
        @last_exception = nil
        @adapter.clear_exception(example_source)
        @adapter.clear_execution_result(example_source)
        @adapter.clear_lets(example_source) if @configuration.clear_lets_on_failure

        true
      rescue StandardError => e
        @last_exception = e
        raise if @configuration.reset_failure_policy == :raise

        false
      end
    end
  end
end
