# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RSpec::Rewind::RetrySummary do
  it 'summarizes retry, flaky, and not retried events' do
    summary = described_class.new
    budget = RSpec::Rewind::RetryBudget.new(2)
    budget.consume!

    summary.record(event(status: :retrying, actual_sleep_seconds: 0.25))
    summary.record(event(status: :flaky))
    summary.record(event(status: :not_retried))

    expect(summary.to_message(budget: budget)).to include(
      '1 flaky examples',
      '1 retry attempts',
      '0.250s spent sleeping',
      '1 not retried',
      'budget 1/2 used'
    )
  end

  it 'can reset counters' do
    summary = described_class.new
    summary.record(event(status: :flaky))

    summary.reset!

    expect(summary.flaky_examples).to eq(0)
  end

  def event(status:, actual_sleep_seconds: nil)
    RSpec::Rewind::Event.new(
      status: status,
      actual_sleep_seconds: actual_sleep_seconds
    )
  end
end
