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
    expect(event.retry_reason).to eq(:exception)
    expect(event.exception_class).to eq('RuntimeError')
    expect(event.exception_message).to eq('flaky')
    expect(event.attempt).to eq(2)
    expect(event.max_attempts).to eq(3)
    expect(event.attempt_durations.size).to eq(2)
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

  it 'emits not_retried callback with a decision reason' do
    callback_events = []

    runner, = build_runner(
      outcomes: [RuntimeError.new('boom'), nil],
      metadata: { rewind: 2, rewind_skip_retry_on: [RuntimeError] },
      configure: ->(config) { config.not_retried_callback = ->(event) { callback_events << event } }
    )

    runner.run

    event = callback_events.fetch(0)
    expect(event).to have_attributes(
      status: :not_retried,
      decision_reason: :skip_retry_on_matched,
      matched_skip_retry_on: 'RuntimeError'
    )
  end

  it 'optionally records retrying and not_retried events to the reporter' do
    reporter = RunnerSpecSupport::CollectingReporter.new

    runner, = build_runner(
      outcomes: [RuntimeError.new('boom'), nil],
      metadata: { rewind: 1, rewind_skip_retry_on: [RuntimeError] },
      configure: lambda do |config|
        config.flaky_reporter = reporter
        config.report_retry_events = true
      end
    )

    runner.run

    expect(reporter.events.map(&:status)).to eq([:not_retried])
  end

  it 'records safe metadata subset in events' do
    reporter = RunnerSpecSupport::CollectingReporter.new

    runner, = build_runner(
      outcomes: [RuntimeError.new('flaky'), nil],
      metadata: { rewind: 1, type: :system, secret: 'hidden' },
      configure: lambda do |config|
        config.flaky_reporter = reporter
        config.metadata_report_keys = %i[type]
      end
    )

    runner.run

    expect(reporter.events.first.metadata).to eq(type: :system)
  end

  it 'invokes before_retry and after_retry hooks' do
    hook_statuses = []

    runner, = build_runner(
      outcomes: [RuntimeError.new('boom'), nil],
      metadata: { rewind: 1 },
      configure: lambda do |config|
        config.before_retry = ->(event) { hook_statuses << [:before, event.actual_sleep_seconds] }
        config.after_retry = ->(event) { hook_statuses << [:after, event.actual_sleep_seconds] }
      end
    )

    runner.run

    expect(hook_statuses.first).to eq([:before, nil])
    expect(hook_statuses.last.first).to eq(:after)
    expect(hook_statuses.last.last).to be_a(Float)
  end

  it 'raises callback errors when strict_callbacks is enabled' do
    runner, = build_runner(
      outcomes: [RuntimeError.new('boom'), nil],
      metadata: { rewind: 1 },
      configure: lambda do |config|
        config.strict_callbacks = true
        config.retry_callback = ->(_event) { raise 'callback failed' }
      end
    )

    expect { runner.run }.to raise_error(RuntimeError, /callback failed/)
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

  it 'can include the top backtrace location in retry failure messages' do
    allow(RSpec.configuration.reporter).to receive(:message)
    error = RuntimeError.new('boom')
    error.set_backtrace(['spec/example_spec.rb:10'])

    runner, = build_runner(
      outcomes: [error, nil],
      metadata: { rewind: 1 },
      configure: lambda do |config|
        config.display_retry_failure_messages = true
        config.display_retry_backtrace_top = true
      end
    )

    runner.run

    expect(RSpec.configuration.reporter).to have_received(:message).with(include('spec/example_spec.rb:10'))
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
