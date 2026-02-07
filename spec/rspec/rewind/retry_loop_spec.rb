# frozen_string_literal: true

require 'spec_helper'
require_relative 'runner_support'

RSpec.describe RSpec::Rewind::RetryLoop do
  it 'runs once without retry when resolved retries is zero' do
    setup = build_setup(resolved_retries: 0, attempt_results: [])

    setup[:retry_loop].run(**base_run_options)

    expect(setup[:example]).to have_received(:run)
    expect(setup[:attempt_runner]).not_to have_received(:run)
  end

  it 'retries once then publishes flaky transition on success' do
    error = RuntimeError.new('boom')
    setup = build_setup(
      resolved_retries: 1,
      attempt_results: [[error, 0.1, true], [nil, 0.2, false]]
    )

    setup[:retry_loop].run(**base_run_options)

    expect_retry_behavior(setup: setup, error: error)
  end

  def build_setup(resolved_retries:, attempt_results:)
    example = instance_spy(RunnerSpecSupport::FakeExample)
    context = instance_double(RSpec::Rewind::ExampleContext, source: :source, id: 'example-id')
    retry_count_resolver = instance_spy(RSpec::Rewind::RetryCountResolver, resolve: resolved_retries)
    attempt_runner = instance_spy(RSpec::Rewind::AttemptRunner)
    retry_gate = instance_spy(RSpec::Rewind::RetryGate, allow?: true)
    retry_transition = instance_spy(RSpec::Rewind::RetryTransition)
    flaky_transition = instance_spy(RSpec::Rewind::FlakyTransition)
    allow(attempt_runner).to receive(:run)
    allow(attempt_runner).to receive(:run).and_return(*attempt_results) unless attempt_results.empty?

    retry_loop = described_class.new(
      example: example,
      context: context,
      retry_count_resolver: retry_count_resolver,
      attempt_runner: attempt_runner,
      retry_gate: retry_gate,
      retry_transition: retry_transition,
      flaky_transition: flaky_transition
    )

    {
      retry_loop: retry_loop,
      example: example,
      attempt_runner: attempt_runner,
      retry_gate: retry_gate,
      retry_transition: retry_transition,
      flaky_transition: flaky_transition
    }
  end

  def expect_retry_behavior(setup:, error:)
    expect(setup[:retry_gate]).to have_received(:allow?).with(
      exception: error,
      retry_number: 1,
      resolved_retries: 1,
      retry_on: nil,
      skip_retry_on: nil,
      retry_if: nil,
      example_id: 'example-id'
    )
    expect(setup[:retry_transition]).to have_received(:perform).with(
      retry_number: 1,
      resolved_retries: 1,
      duration: 0.1,
      exception: error,
      backoff: nil,
      wait: nil,
      example_source: :source
    )
    expect(setup[:flaky_transition]).to have_received(:perform).with(
      attempt: 2,
      retries: 1,
      duration: 0.2
    )
  end

  def base_run_options
    {
      retries: nil,
      backoff: nil,
      wait: nil,
      retry_on: nil,
      skip_retry_on: nil,
      retry_if: nil
    }
  end
end
