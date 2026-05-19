# frozen_string_literal: true

module RSpec
  module Rewind
    class RunnerComponentFactory
      def build(example:, configuration:, context:, logger:)
        RunnerComponents.new(
          example: example,
          configuration: configuration,
          context: context,
          logger: logger
        )
      end
    end
  end
end
