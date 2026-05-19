# frozen_string_literal: true

module RSpec
  module Rewind
    class ExampleStateResetter
      def initialize(configuration:, adapter: RSpecAdapter.new)
        @configuration = configuration
        @adapter = adapter
      end

      def reset(example_source)
        @adapter.clear_exception(example_source)
        @adapter.clear_execution_result(example_source)
        @adapter.clear_lets(example_source) if @configuration.clear_lets_on_failure
      rescue StandardError
        raise if @configuration.reset_failure_policy == :raise

        false
      end
    end
  end
end
