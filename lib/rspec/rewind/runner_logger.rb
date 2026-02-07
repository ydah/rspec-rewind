# frozen_string_literal: true

module RSpec
  module Rewind
    class RunnerLogger
      def initialize(configuration:, warn_output:)
        @configuration = configuration
        @warn_output = warn_output
      end

      def reporter_message(message)
        if defined?(::RSpec) && ::RSpec.respond_to?(:configuration)
          reporter = ::RSpec.configuration.reporter
          reporter&.message(message)
        end
      rescue StandardError
        @warn_output.call(message)
      end

      def debug(message)
        return unless @configuration.verbose

        reporter_message("[rspec-rewind] #{message}")
      end
    end
  end
end
