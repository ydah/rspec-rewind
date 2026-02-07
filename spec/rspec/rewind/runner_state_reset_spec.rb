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
end
