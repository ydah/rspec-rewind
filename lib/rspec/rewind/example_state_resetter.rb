# frozen_string_literal: true

module RSpec
  module Rewind
    class ExampleStateResetter
      def initialize(configuration:)
        @configuration = configuration
      end

      def reset(example_source)
        clear_exception(example_source)
        clear_execution_result(example_source)
        clear_lets(example_source) if @configuration.clear_lets_on_failure
      end

      private

      def clear_exception(example_source)
        if example_source.respond_to?(:clear_exception)
          example_source.clear_exception
        elsif example_source.instance_variable_defined?(:@exception)
          example_source.instance_variable_set(:@exception, nil)
        end
      end

      def clear_execution_result(example_source)
        return unless example_source.respond_to?(:execution_result)

        result = example_source.execution_result
        return unless result

        set_if_writer(result, :status, nil)
        set_if_writer(result, :exception, nil)
        set_if_writer(result, :pending_message, nil)
        set_if_writer(result, :run_time, nil)
      end

      def clear_lets(example_source)
        return unless example_source.respond_to?(:example_group_instance)

        group_instance = example_source.example_group_instance
        return unless group_instance

        if group_instance.respond_to?(:clear_lets)
          group_instance.clear_lets
        elsif group_instance.instance_variable_defined?(:@__memoized)
          group_instance.instance_variable_set(:@__memoized, nil)
        end
      end

      def set_if_writer(target, attribute, value)
        writer = "#{attribute}="
        target.public_send(writer, value) if target.respond_to?(writer)
      end
    end
  end
end
