# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RSpec::Rewind::FlakyTransition do
  it 'builds flaky event and publishes it' do
    builder = instance_spy(RSpec::Rewind::RetryEventBuilder)
    notifier = instance_spy(RSpec::Rewind::RetryNotifier)
    transition = described_class.new(event_builder: builder, notifier: notifier)
    event = instance_double(RSpec::Rewind::Event)
    allow(builder).to receive(:build).and_return(event)

    exception = RuntimeError.new('first failure')
    transition.perform(
      attempt: 2,
      retries: 3,
      duration: 0.2,
      exception: exception,
      total_duration: 0.4,
      attempt_durations: [0.2, 0.2],
      first_failure_duration: 0.2,
      sleep_total: 0.0
    )

    expect(builder).to have_received(:build).with(
      status: :flaky,
      retry_reason: :exception,
      attempt: 2,
      retries: 3,
      duration: 0.2,
      total_duration: 0.4,
      attempt_durations: [0.2, 0.2],
      first_failure_duration: 0.2,
      sleep_seconds: 0.0,
      scheduled_sleep_seconds: 0.0,
      actual_sleep_seconds: 0.0,
      sleep_total: 0.0,
      budget_decision: nil,
      exception: exception
    )
    expect(notifier).to have_received(:publish_flaky).with(event)
  end
end
