# frozen_string_literal: true

module RSpec
  module Rewind
    PUBLIC_API = [
      Backoff,
      Configuration,
      Event,
      FileRetryBudget,
      FlakyReporter,
      RetryBudget,
      RetryDecision,
      RetryPolicy,
      Runner
    ].freeze

    INTERNAL_API = [
      AttemptRunner,
      ExampleContext,
      ExampleMethods,
      ExampleStateResetter,
      FlakyTransition,
      RetryCountResolver,
      RetryDelayResolver,
      RetryEventBuilder,
      RetryGate,
      RetryLoop,
      RetryNotifier,
      RetryTransition,
      RunnerComponentFactory,
      RunnerComponents,
      RunnerLogger,
      RSpecAdapter
    ].freeze
  end
end
