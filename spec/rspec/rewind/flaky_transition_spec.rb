# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RSpec::Rewind::FlakyTransition do
  it 'builds flaky event and publishes it' do
    builder = instance_spy(RSpec::Rewind::RetryEventBuilder)
    notifier = instance_spy(RSpec::Rewind::RetryNotifier)
    transition = described_class.new(event_builder: builder, notifier: notifier)
    event = instance_double(RSpec::Rewind::Event)
    allow(builder).to receive(:build).and_return(event)

    transition.perform(attempt: 2, retries: 3, duration: 0.2)

    expect(builder).to have_received(:build).with(
      status: :flaky,
      retry_reason: nil,
      attempt: 2,
      retries: 3,
      duration: 0.2,
      sleep_seconds: 0.0,
      exception: nil
    )
    expect(notifier).to have_received(:publish_flaky).with(event)
  end
end
