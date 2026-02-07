# frozen_string_literal: true

require 'spec_helper'
require_relative 'runner_support'

RSpec.describe RSpec::Rewind::Runner do
  include RunnerSpecSupport

  it 'records flaky example once it passes after a retry' do
    reporter = RunnerSpecSupport::CollectingReporter.new

    runner, = build_runner(
      outcomes: [RuntimeError.new('flaky'), nil],
      metadata: { rewind: 2 },
      configure: ->(config) { config.flaky_reporter = reporter }
    )

    runner.run

    expect(reporter.events.size).to eq(1)
    event = reporter.events.first
    expect(event.schema_version).to eq(1)
    expect(event.status).to eq(:flaky)
    expect(event.retry_reason).to be_nil
    expect(event.attempt).to eq(2)
  end

  it 'invokes retry_callback with retrying event' do
    callback_events = []

    runner, = build_runner(
      outcomes: [RuntimeError.new('boom'), nil],
      metadata: { rewind: 2 },
      configure: ->(config) { config.retry_callback = ->(event) { callback_events << event } }
    )

    runner.run

    expect(callback_events.size).to eq(1)
    event = callback_events.first
    expect(event.schema_version).to eq(1)
    expect(event.status).to eq(:retrying)
    expect(event.retry_reason).to eq(:exception)
    expect(event.attempt).to eq(1)
  end

  it 'swallows exceptions raised by flaky_reporter' do
    failing_reporter = Class.new do
      def record(_event)
        raise 'report failed'
      end
    end.new

    runner, example, = build_runner(
      outcomes: [RuntimeError.new('boom'), nil],
      metadata: { rewind: 1 },
      configure: ->(config) { config.flaky_reporter = failing_reporter }
    )

    expect { runner.run }.not_to raise_error
    expect(example.run_calls).to eq(2)
  end

  it 'invokes flaky_callback even when flaky_reporter raises' do
    failing_reporter = Class.new do
      def record(_event)
        raise 'report failed'
      end
    end.new
    callback_events = []

    runner, = build_runner(
      outcomes: [RuntimeError.new('boom'), nil],
      metadata: { rewind: 1 },
      configure: lambda do |config|
        config.flaky_reporter = failing_reporter
        config.flaky_callback = ->(event) { callback_events << event }
      end
    )

    expect { runner.run }.not_to raise_error
    expect(callback_events.size).to eq(1)
  end

  it 'swallows exceptions raised by flaky_callback' do
    runner, example, = build_runner(
      outcomes: [RuntimeError.new('boom'), nil],
      metadata: { rewind: 1 },
      configure: ->(config) { config.flaky_callback = ->(_event) { raise 'callback failed' } }
    )

    expect { runner.run }.not_to raise_error
    expect(example.run_calls).to eq(2)
  end

  it 'displays retry failure messages when enabled' do
    allow(RSpec.configuration.reporter).to receive(:message)

    runner, = build_runner(
      outcomes: [RuntimeError.new('boom'), nil],
      metadata: { rewind: 1 },
      configure: ->(config) { config.display_retry_failure_messages = true }
    )

    runner.run

    expect(RSpec.configuration.reporter).to have_received(:message).with(include('RuntimeError: boom'))
  end

  it 'emits debug messages when verbose is enabled' do
    allow(RSpec.configuration.reporter).to receive(:message)

    runner, = build_runner(
      outcomes: [RuntimeError.new('boom'), nil],
      metadata: { rewind: 1 },
      configure: ->(config) { config.verbose = true }
    )

    runner.run

    expect(RSpec.configuration.reporter).to have_received(:message).with(match(%r{\[rspec-rewind\] retry 1/1}))
  end

  it 'swallows exceptions raised by retry_callback' do
    runner, example, = build_runner(
      outcomes: [RuntimeError.new('boom'), nil],
      metadata: { rewind: 2 },
      configure: ->(config) { config.retry_callback = ->(_event) { raise 'callback failed' } }
    )

    expect { runner.run }.not_to raise_error
    expect(example.run_calls).to eq(2)
  end
end
