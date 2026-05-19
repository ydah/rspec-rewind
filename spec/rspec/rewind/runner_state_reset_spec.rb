# frozen_string_literal: true

require 'spec_helper'
require_relative 'runner_support'

RSpec.describe RSpec::Rewind::Runner do
  include RunnerSpecSupport

  it 'clears lets after retry when clear_lets_on_failure is enabled' do
    runner, example, = build_runner(
      outcomes: [RuntimeError.new('boom'), nil],
      metadata: { rewind: 2 }
    )

    runner.run

    expect(example.example_group_instance.clear_lets_calls).to eq(1)
  end

  it 'does not clear lets when clear_lets_on_failure is false' do
    runner, example, = build_runner(
      outcomes: [RuntimeError.new('boom'), nil],
      metadata: { rewind: 2 },
      configure: ->(config) { config.clear_lets_on_failure = false }
    )

    runner.run

    expect(example.example_group_instance.clear_lets_calls).to eq(0)
  end

  it 'clears exception ivar when clear_exception is unavailable' do
    runner, example, = build_runner(
      outcomes: [RuntimeError.new('boom'), nil],
      metadata: { rewind: 1 }
    )

    example.singleton_class.undef_method(:clear_exception)
    runner.run

    expect(example.exception).to be_nil
  end

  it 'clears legacy memoized lets ivar when clear_lets is unavailable' do
    runner, example, = build_runner(
      outcomes: [RuntimeError.new('boom'), nil],
      metadata: { rewind: 1 }
    )

    legacy_group = Object.new
    legacy_group.instance_variable_set(:@__memoized, { value: 1 })
    example.instance_variable_set(:@example_group_instance, legacy_group)

    runner.run

    expect(legacy_group.instance_variable_get(:@__memoized)).to be_nil
  end

  it 'can continue when state reset fails and policy allows it' do
    reporter = RunnerSpecSupport::CollectingReporter.new
    runner, example, = build_runner(
      outcomes: [RuntimeError.new('boom'), nil],
      metadata: { rewind: 1 },
      configure: lambda { |config|
        config.flaky_reporter = reporter
        config.report_retry_events = true
        config.reset_failure_policy = :continue
      }
    )

    example.define_singleton_method(:clear_exception) { raise 'reset failed' }

    expect { runner.run }.not_to raise_error
    expect(example.run_calls).to eq(2)
    expect(reporter.events.map(&:status)).to include(:reset_failed, :retrying)
    expect(reporter.events.find { |event| event.status == :reset_failed }).to have_attributes(
      decision_reason: :state_reset_failed,
      exception_message: 'reset failed'
    )
  end

  it 'reports state reset failures before raising when the reset policy is strict' do
    reporter = RunnerSpecSupport::CollectingReporter.new
    runner, example, = build_runner(
      outcomes: [RuntimeError.new('boom'), nil],
      metadata: { rewind: 1 },
      configure: lambda { |config|
        config.flaky_reporter = reporter
        config.report_retry_events = true
      }
    )

    example.define_singleton_method(:clear_exception) { raise 'reset failed' }

    expect { runner.run }.to raise_error(RuntimeError, 'reset failed')
    expect(example.run_calls).to eq(1)
    expect(reporter.events.map(&:status)).to eq([:reset_failed])
    expect(reporter.events.first).to have_attributes(
      retry_reason: :state_reset,
      decision_reason: :state_reset_failed,
      exception_class: 'RuntimeError',
      exception_message: 'reset failed'
    )
  end
end
