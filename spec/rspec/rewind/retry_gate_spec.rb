# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RSpec::Rewind::RetryGate do
  subject(:gate) do
    described_class.new(
      configuration: configuration,
      retry_policy: retry_policy,
      debug: ->(message) { debug_messages << message }
    )
  end

  let(:retry_budget) { instance_spy(RSpec::Rewind::RetryBudget) }
  let(:retry_policy) { instance_spy(RSpec::Rewind::RetryPolicy) }
  let(:debug_messages) { [] }
  let(:configuration) do
    instance_double(
      RSpec::Rewind::Configuration,
      retry_budget: retry_budget,
      max_elapsed_time: nil,
      max_total_sleep: nil,
      dry_run: false
    )
  end

  before do
    allow(retry_budget).to receive(:remaining).and_return(Float::INFINITY)
  end

  it 'returns false when retry count is exhausted' do
    allow(retry_policy).to receive(:decision).and_return(policy_decision(true))
    allow(retry_budget).to receive(:consume).and_return(budget_decision(true))

    allowed = allow_retry?(retry_number: 2, resolved_retries: 1)

    expect(allowed).to be(false)
    expect(retry_policy).not_to have_received(:decision)
    expect(retry_budget).not_to have_received(:consume)
  end

  it 'returns false when retry policy blocks retry' do
    allow(retry_policy).to receive(:decision).and_return(policy_decision(false, reason: :predicate_rejected))
    allow(retry_budget).to receive(:consume).and_return(budget_decision(true))

    allowed = allow_retry?

    expect(allowed).to be(false)
    expect(retry_budget).not_to have_received(:consume)
  end

  it 'returns false and emits debug message when retry budget is exhausted' do
    allow(retry_policy).to receive(:decision).and_return(policy_decision(true))
    allow(retry_budget).to receive(:consume).and_return(budget_decision(false, limit: 1, used: 1, remaining: 0))

    allowed = allow_retry?(example_id: 'spec-id')

    expect(allowed).to be(false)
    expect(debug_messages).to include('retry budget exhausted for spec-id')
  end

  it 'returns true when retries are available and policy allows' do
    allow(retry_policy).to receive(:decision).and_return(policy_decision(true))
    allow(retry_budget).to receive(:consume).and_return(budget_decision(true, limit: 2, used: 1, remaining: 1))

    allowed = allow_retry?

    expect(allowed).to be(true)
    expect(debug_messages).to be_empty
  end

  it 'returns a budget exhausted decision with budget state' do
    allow(retry_policy).to receive(:decision).and_return(policy_decision(true))
    allow(retry_budget).to receive(:consume).and_return(budget_decision(false, limit: 1, used: 1, remaining: 0))

    decision = gate.decision(
      exception: RuntimeError.new('boom'),
      retry_number: 1,
      resolved_retries: 2,
      retry_on: [RuntimeError],
      skip_retry_on: [],
      retry_if: nil,
      example_id: 'example-1'
    )

    expect(decision).to have_attributes(
      allowed?: false,
      reason: :budget_exhausted
    )
    expect(decision.budget_decision.remaining).to eq(0)
  end

  def allow_retry?(**overrides)
    gate.allow?(
      exception: RuntimeError.new('boom'),
      retry_number: 1,
      resolved_retries: 2,
      retry_on: [RuntimeError],
      skip_retry_on: [],
      retry_if: nil,
      example_id: 'example-1',
      **overrides
    )
  end

  def policy_decision(allowed, reason: :allowed)
    RSpec::Rewind::RetryDecisionResult.new(allowed: allowed, reason: reason)
  end

  def budget_decision(allowed, limit: nil, used: 0, remaining: Float::INFINITY)
    RSpec::Rewind::BudgetDecision.new(
      allowed: allowed,
      limit: limit,
      used: used,
      remaining: remaining
    )
  end
end
