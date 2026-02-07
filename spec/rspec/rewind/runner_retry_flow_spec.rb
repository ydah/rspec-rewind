# frozen_string_literal: true

require 'spec_helper'
require_relative 'runner_support'

RSpec.describe RSpec::Rewind::Runner do
  include RunnerSpecSupport

  it 'retries and eventually passes' do
    runner, example, = build_runner(
      outcomes: [RuntimeError.new('boom'), nil],
      metadata: { rewind: 2 }
    )

    runner.run

    expect(example.run_calls).to eq(2)
    expect(example.exception).to be_nil
  end

  it 'does not retry when skip list matches' do
    runner, example, = build_runner(
      outcomes: [RuntimeError.new('fatal'), nil],
      metadata: { rewind: 2, rewind_skip_retry_on: [RuntimeError] }
    )

    runner.run

    expect(example.run_calls).to eq(1)
  end

  it 'respects retry budget' do
    runner, example, = build_runner(
      outcomes: [RuntimeError.new('a'), RuntimeError.new('b'), nil],
      metadata: { rewind: 3 },
      configure: ->(config) { config.retry_budget = 1 }
    )

    runner.run

    expect(example.run_calls).to eq(2)
  end

  it 'sleeps between retries when a backoff strategy is given' do
    allow(Kernel).to receive(:sleep)

    runner, = build_runner(
      outcomes: [RuntimeError.new('temporary'), nil],
      metadata: { rewind: 2 }
    )

    runner.run(backoff: ->(**_) { 0.5 })

    expect(Kernel).to have_received(:sleep).with(0.5)
  end

  it 'raises when backoff resolves to non-numeric delay' do
    runner, = build_runner(
      outcomes: [RuntimeError.new('boom'), nil],
      metadata: { rewind: 1 }
    )

    expect do
      runner.run(backoff: ->(**_) { :invalid })
    end.to raise_error(ArgumentError, /delay must be numeric/)
  end

  it 'does not retry when retry_on does not match the exception' do
    runner, example, = build_runner(
      outcomes: [RuntimeError.new('boom'), nil],
      metadata: { rewind: 2, rewind_retry_on: [IOError] }
    )

    runner.run

    expect(example.run_calls).to eq(1)
  end

  it 'supports rewind_skip_retry_on metadata key' do
    runner, example, = build_runner(
      outcomes: [RuntimeError.new('boom'), nil],
      metadata: { rewind: 2, rewind_skip_retry_on: [RuntimeError] }
    )

    runner.run

    expect(example.run_calls).to eq(1)
  end

  it 'uses explicit retries argument before metadata and config defaults' do
    runner, example, = build_runner(
      outcomes: [RuntimeError.new('a'), RuntimeError.new('b'), nil],
      metadata: { rewind: 3 },
      configure: ->(config) { config.default_retries = 5 }
    )

    runner.run(retries: 1)

    expect(example.run_calls).to eq(2)
  end

  it 'uses metadata rewind before configuration default' do
    runner, example, = build_runner(
      outcomes: [RuntimeError.new('a'), RuntimeError.new('b'), nil],
      metadata: { rewind: 1 },
      configure: ->(config) { config.default_retries = 5 }
    )

    runner.run

    expect(example.run_calls).to eq(2)
  end

  it 'uses metadata retry alias before configuration default' do
    runner, example, = build_runner(
      outcomes: [RuntimeError.new('a'), RuntimeError.new('b'), nil],
      metadata: { retry: 1 },
      configure: ->(config) { config.default_retries = 5 }
    )

    runner.run

    expect(example.run_calls).to eq(2)
  end

  it 'treats metadata rewind: true as an enable flag and uses defaults' do
    runner, example, = build_runner(
      outcomes: [RuntimeError.new('a'), nil],
      metadata: { rewind: true },
      configure: ->(config) { config.default_retries = 1 }
    )

    runner.run

    expect(example.run_calls).to eq(2)
  end

  it 'treats metadata retry: true as an enable flag and uses defaults' do
    runner, example, = build_runner(
      outcomes: [RuntimeError.new('a'), nil],
      metadata: { retry: true },
      configure: ->(config) { config.default_retries = 1 }
    )

    runner.run

    expect(example.run_calls).to eq(2)
  end

  it 'treats metadata rewind: false as zero retries' do
    runner, example, = build_runner(
      outcomes: [RuntimeError.new('a'), nil],
      metadata: { rewind: false },
      configure: ->(config) { config.default_retries = 3 }
    )

    runner.run

    expect(example.run_calls).to eq(1)
  end

  it 'treats metadata retry: false as zero retries' do
    runner, example, = build_runner(
      outcomes: [RuntimeError.new('a'), nil],
      metadata: { retry: false },
      configure: ->(config) { config.default_retries = 3 }
    )

    runner.run

    expect(example.run_calls).to eq(1)
  end

  it 'prefers metadata rewind over metadata retry when both are set' do
    runner, example, = build_runner(
      outcomes: [RuntimeError.new('a'), nil],
      metadata: { rewind: false, retry: 2 },
      configure: ->(config) { config.default_retries = 3 }
    )

    runner.run

    expect(example.run_calls).to eq(1)
  end

  it 'uses configuration default when no override is provided' do
    runner, example, = build_runner(
      outcomes: [RuntimeError.new('a'), RuntimeError.new('b'), nil],
      configure: ->(config) { config.default_retries = 1 }
    )

    runner.run

    expect(example.run_calls).to eq(2)
  end

  it 'uses RSPEC_REWIND_RETRIES env var before explicit retries' do
    original = ENV.fetch('RSPEC_REWIND_RETRIES', nil)
    ENV['RSPEC_REWIND_RETRIES'] = '0'

    runner, example, = build_runner(
      outcomes: [RuntimeError.new('a'), nil],
      metadata: { rewind: 3 }
    )

    runner.run(retries: 2)

    expect(example.run_calls).to eq(1)
  ensure
    ENV['RSPEC_REWIND_RETRIES'] = original
  end

  it 'treats explicit retries: false as zero retries' do
    runner, example, = build_runner(
      outcomes: [RuntimeError.new('a'), nil],
      metadata: { rewind: 2 }
    )

    runner.run(retries: false)

    expect(example.run_calls).to eq(1)
  end

  it 'treats explicit retries: true as no override' do
    runner, example, = build_runner(
      outcomes: [RuntimeError.new('a'), nil],
      metadata: { rewind: 1 },
      configure: ->(config) { config.default_retries = 3 }
    )

    runner.run(retries: true)

    expect(example.run_calls).to eq(2)
  end

  it 'raises when RSPEC_REWIND_RETRIES is invalid' do
    original = ENV.fetch('RSPEC_REWIND_RETRIES', nil)
    ENV['RSPEC_REWIND_RETRIES'] = 'many'
    runner, = build_runner(outcomes: [nil], metadata: {})

    expect do
      runner.run(retries: 2)
    end.to raise_error(ArgumentError, /RSPEC_REWIND_RETRIES must be a non-negative integer/)
  ensure
    ENV['RSPEC_REWIND_RETRIES'] = original
  end

  it 'raises when retries is negative' do
    runner, = build_runner(outcomes: [nil], metadata: {})

    expect { runner.run(retries: -1) }.to raise_error(ArgumentError, /retries must be >= 0/)
  end

  it 'retries when the example raises and then passes' do
    runner, example, = build_runner(
      outcomes: [RuntimeError.new('boom'), nil],
      metadata: { rewind: 2 },
      example_class: RunnerSpecSupport::FakeRaisingExample
    )

    expect { runner.run }.not_to raise_error
    expect(example.run_calls).to eq(2)
  end

  it 're-raises the final exception when retries are exhausted' do
    runner, example, = build_runner(
      outcomes: [RuntimeError.new('first'), RuntimeError.new('last')],
      metadata: { rewind: 1 },
      example_class: RunnerSpecSupport::FakeRaisingExample
    )

    expect { runner.run }.to raise_error(RuntimeError, 'last')
    expect(example.run_calls).to eq(2)
  end
end
