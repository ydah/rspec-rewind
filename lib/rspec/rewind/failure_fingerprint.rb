# frozen_string_literal: true

module RSpec
  module Rewind
    module FailureFingerprint
      module_function

      def build(exception)
        return nil unless exception

        [
          exception.class.name,
          exception.message,
          exception.backtrace&.first
        ].join(':')
      end
    end
  end
end
