# frozen_string_literal: true

module RSpec
  module Rewind
    module ExampleMethods
      def run_with_rewind(options = {})
        normalized = normalize_options(options)

        Runner.new(example: self, configuration: RSpec::Rewind.configuration).run(**normalized)
      end

      private

      def normalize_options(options)
        return {} if options.nil? || options.empty?

        symbolized = options.transform_keys(&:to_sym)

        {
          retries: symbolized[:retries],
          backoff: symbolized[:backoff],
          wait: symbolized[:wait],
          retry_on: symbolized[:retry_on],
          skip_retry_on: symbolized[:skip_retry_on],
          retry_if: symbolized[:retry_if]
        }.compact
      end
    end
  end
end
