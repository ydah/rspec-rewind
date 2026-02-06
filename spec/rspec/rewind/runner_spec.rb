# frozen_string_literal: true

require "spec_helper"

RSpec.describe RSpec::Rewind::Runner do
  class FakeExecutionResult
    attr_accessor :status, :exception, :pending_message, :run_time
  end

  class FakeExampleGroupInstance
    attr_reader :clear_lets_calls

    def initialize
      @clear_lets_calls = 0
    end

    def clear_lets
      @clear_lets_calls += 1
    end
  end

  class FakeExample
    attr_reader :metadata,
                :run_calls,
                :id,
                :full_description,
                :location,
                :execution_result,
                :example_group_instance

    attr_accessor :exception

    def initialize(outcomes:, metadata: {})
      @outcomes = outcomes.dup
      @metadata = metadata
      @run_calls = 0
      @id = "spec/fake_spec.rb[1:1]"
      @full_description = "fake example"
      @location = "spec/fake_spec.rb:1"
      @execution_result = FakeExecutionResult.new
      @example_group_instance = FakeExampleGroupInstance.new
      @exception = nil
    end

    def run
      @run_calls += 1
      @exception = @outcomes.shift
    end

    def clear_exception
      @exception = nil
    end
  end

  class CollectingReporter
    attr_reader :events

    def initialize
      @events = []
    end

    def record(event)
      @events << event
    end
  end

  def build_runner(outcomes:, metadata: {}, configure: nil)
    config = RSpec::Rewind::Configuration.new
    configure&.call(config)

    example = FakeExample.new(outcomes: outcomes, metadata: metadata)
    runner = described_class.new(example: example, configuration: config)
    [runner, example, config]
  end

  it "retries and eventually passes" do
    runner, example, = build_runner(
      outcomes: [RuntimeError.new("boom"), nil],
      metadata: { rewind: 2 }
    )

    runner.run

    expect(example.run_calls).to eq(2)
    expect(example.exception).to be_nil
    expect(example.example_group_instance.clear_lets_calls).to eq(1)
  end

  it "does not retry when skip list matches" do
    runner, example, = build_runner(
      outcomes: [RuntimeError.new("fatal"), nil],
      metadata: { rewind: 2, rewind_skip_on: [RuntimeError] }
    )

    runner.run

    expect(example.run_calls).to eq(1)
  end

  it "respects retry budget" do
    runner, example, = build_runner(
      outcomes: [RuntimeError.new("a"), RuntimeError.new("b"), nil],
      metadata: { rewind: 3 },
      configure: lambda do |config|
        config.retry_budget = 1
      end
    )

    runner.run

    expect(example.run_calls).to eq(2)
  end

  it "records flaky example once it passes after a retry" do
    reporter = CollectingReporter.new

    runner, = build_runner(
      outcomes: [RuntimeError.new("flaky"), nil],
      metadata: { rewind: 2 },
      configure: lambda do |config|
        config.flaky_reporter = reporter
      end
    )

    runner.run

    expect(reporter.events.size).to eq(1)
    event = reporter.events.first
    expect(event.status).to eq(:flaky)
    expect(event.attempt).to eq(2)
  end

  it "sleeps between retries when a backoff strategy is given" do
    allow(Kernel).to receive(:sleep)

    runner, = build_runner(
      outcomes: [RuntimeError.new("temporary"), nil],
      metadata: { rewind: 2 }
    )

    runner.run(backoff: ->(**_) { 0.5 })

    expect(Kernel).to have_received(:sleep).with(0.5)
  end

  it "does not retry when retry_on does not match the exception" do
    runner, example, = build_runner(
      outcomes: [RuntimeError.new("boom"), nil],
      metadata: { rewind: 2, rewind_retry_on: [IOError] }
    )

    runner.run

    expect(example.run_calls).to eq(1)
  end

  it "supports rewind_skip_retry_on metadata alias" do
    runner, example, = build_runner(
      outcomes: [RuntimeError.new("boom"), nil],
      metadata: { rewind: 2, rewind_skip_retry_on: [RuntimeError] }
    )

    runner.run

    expect(example.run_calls).to eq(1)
  end

  it "uses explicit retries argument before metadata and config defaults" do
    runner, example, = build_runner(
      outcomes: [RuntimeError.new("a"), RuntimeError.new("b"), nil],
      metadata: { rewind: 3 },
      configure: lambda do |config|
        config.default_retries = 5
      end
    )

    runner.run(retries: 1)

    expect(example.run_calls).to eq(2)
  end

  it "uses RSPEC_REWIND_RETRIES env var before explicit retries" do
    original = ENV["RSPEC_REWIND_RETRIES"]
    ENV["RSPEC_REWIND_RETRIES"] = "0"

    runner, example, = build_runner(
      outcomes: [RuntimeError.new("a"), nil],
      metadata: { rewind: 3 }
    )

    runner.run(retries: 2)

    expect(example.run_calls).to eq(1)
  ensure
    ENV["RSPEC_REWIND_RETRIES"] = original
  end

  it "does not clear lets when clear_lets_on_failure is false" do
    runner, example, = build_runner(
      outcomes: [RuntimeError.new("boom"), nil],
      metadata: { rewind: 2 },
      configure: lambda do |config|
        config.clear_lets_on_failure = false
      end
    )

    runner.run

    expect(example.example_group_instance.clear_lets_calls).to eq(0)
  end

  it "invokes retry_callback with retrying event" do
    callback_events = []

    runner, = build_runner(
      outcomes: [RuntimeError.new("boom"), nil],
      metadata: { rewind: 2 },
      configure: lambda do |config|
        config.retry_callback = ->(event) { callback_events << event }
      end
    )

    runner.run

    expect(callback_events.size).to eq(1)
    event = callback_events.first
    expect(event.status).to eq(:retrying)
    expect(event.attempt).to eq(1)
  end

  it "swallows exceptions raised by retry_callback" do
    runner, example, = build_runner(
      outcomes: [RuntimeError.new("boom"), nil],
      metadata: { rewind: 2 },
      configure: lambda do |config|
        config.retry_callback = ->(_event) { raise "callback failed" }
      end
    )

    expect { runner.run }.not_to raise_error
    expect(example.run_calls).to eq(2)
  end

  it "raises when retries is negative" do
    runner, = build_runner(outcomes: [nil], metadata: {})

    expect { runner.run(retries: -1) }.to raise_error(ArgumentError, /retries must be >= 0/)
  end
end
