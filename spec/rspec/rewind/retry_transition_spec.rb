# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RSpec::Rewind::RetryTransition do
  it 'builds retry event, notifies, resets state, and sleeps' do
    params = retry_params(resolved_retries: 2, duration: 0.25, backoff: :backoff_strategy, wait: nil)
    context = run_transition(
      display_retry_failure_messages: true,
      resolved_sleep: 0.5,
      retry_params: params
    )

    expect_resolve_called(context)
    expect_event_built(context, sleep_seconds: 0.5)
    expect(context[:notifier]).to have_received(:notify_retry).with(context[:event])
    expect(context[:notifier]).to have_received(:show_failure_message).with(params[:exception])
    expect(context[:resetter]).to have_received(:reset).with(params[:example_source])
    expect(context[:sleep_calls]).to eq([0.5])
  end

  it 'skips failure message and sleep when disabled or delay is zero' do
    params = retry_params(resolved_retries: 1, duration: 0.1, backoff: nil, wait: 0.0)
    context = run_transition(
      display_retry_failure_messages: false,
      resolved_sleep: 0.0,
      retry_params: params
    )

    expect(context[:notifier]).to have_received(:notify_retry).with(context[:event])
    expect(context[:notifier]).not_to have_received(:show_failure_message)
    expect(context[:resetter]).to have_received(:reset).with(params[:example_source])
    expect(context[:sleep_calls]).to be_empty
  end

  def retry_params(resolved_retries:, duration:, backoff:, wait:)
    {
      retry_number: 1,
      resolved_retries: resolved_retries,
      duration: duration,
      exception: RuntimeError.new('boom'),
      backoff: backoff,
      wait: wait,
      example_source: Object.new
    }
  end

  def run_transition(display_retry_failure_messages:, resolved_sleep:, retry_params:)
    transition, resolver, builder, notifier, resetter, sleep_calls = build_transition(
      display_retry_failure_messages: display_retry_failure_messages,
      resolved_sleep: resolved_sleep
    )
    event = instance_double(RSpec::Rewind::Event)
    allow(builder).to receive(:build).and_return(event)

    transition.perform(**retry_params)

    {
      resolver: resolver,
      builder: builder,
      notifier: notifier,
      resetter: resetter,
      sleep_calls: sleep_calls,
      event: event,
      retry_params: retry_params
    }
  end

  def expect_resolve_called(context)
    params = context[:retry_params]
    expect(context[:resolver]).to have_received(:resolve).with(
      retry_number: params[:retry_number],
      backoff: params[:backoff],
      wait: params[:wait],
      exception: params[:exception]
    )
  end

  def expect_event_built(context, sleep_seconds:)
    params = context[:retry_params]
    expect(context[:builder]).to have_received(:build).with(
      status: :retrying,
      retry_reason: :exception,
      attempt: params[:retry_number],
      retries: params[:resolved_retries],
      duration: params[:duration],
      sleep_seconds: sleep_seconds,
      exception: params[:exception]
    )
  end

  def build_transition(display_retry_failure_messages:, resolved_sleep:)
    configuration = instance_double(
      RSpec::Rewind::Configuration,
      display_retry_failure_messages: display_retry_failure_messages
    )
    resolver = instance_spy(RSpec::Rewind::RetryDelayResolver, resolve: resolved_sleep)
    builder = instance_spy(RSpec::Rewind::RetryEventBuilder)
    notifier = instance_spy(RSpec::Rewind::RetryNotifier)
    resetter = instance_spy(RSpec::Rewind::ExampleStateResetter)
    sleep_calls = []

    transition = described_class.new(
      configuration: configuration,
      retry_delay_resolver: resolver,
      event_builder: builder,
      notifier: notifier,
      state_resetter: resetter,
      sleep: ->(seconds) { sleep_calls << seconds }
    )

    [transition, resolver, builder, notifier, resetter, sleep_calls]
  end
end
