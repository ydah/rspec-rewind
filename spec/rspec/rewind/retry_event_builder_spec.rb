# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RSpec::Rewind::RetryEventBuilder do
  it 'builds immutable events with fallback example source fields' do
    event = described_class.new(example_source: Object.new).build(
      status: :not_retried,
      retry_reason: :exception,
      decision_reason: :retry_on_not_matched,
      attempt: 1,
      retries: 2,
      duration: 0.1,
      sleep_seconds: 0.0,
      exception: RuntimeError.new('boom')
    )

    expect(event).to have_attributes(
      example_id: 'unknown',
      description: 'unknown',
      location: 'unknown',
      max_attempts: 3,
      failure_fingerprint: include('RuntimeError:boom')
    )
    expect(event.to_h).to include(status: :not_retried, decision_reason: :retry_on_not_matched)
    expect(event).to be_frozen
  end

  it 'adds budget state when provided' do
    budget = RSpec::Rewind::BudgetDecision.new(allowed: true, limit: 2, used: 1, remaining: 1)
    event = described_class.new(example_source: Object.new).build(
      status: :retrying,
      retry_reason: :exception,
      attempt: 1,
      retries: 2,
      duration: 0.1,
      sleep_seconds: 0.0,
      budget_decision: budget,
      exception: RuntimeError.new('boom')
    )

    expect(event).to have_attributes(
      budget_limit: 2,
      budget_used: 1,
      budget_remaining: 1
    )
  end
end
