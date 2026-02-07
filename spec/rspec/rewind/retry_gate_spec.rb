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
  let(:configuration) { instance_double(RSpec::Rewind::Configuration, retry_budget: retry_budget) }

  it 'returns false when retry count is exhausted' do
    allow(retry_policy).to receive(:retry_allowed?).and_return(true)
    allow(retry_budget).to receive(:consume!).and_return(true)

    allowed = allow_retry?(retry_number: 2, resolved_retries: 1)

    expect(allowed).to be(false)
    expect(retry_policy).not_to have_received(:retry_allowed?)
    expect(retry_budget).not_to have_received(:consume!)
  end

  it 'returns false when retry policy blocks retry' do
    allow(retry_policy).to receive(:retry_allowed?).and_return(false)
    allow(retry_budget).to receive(:consume!).and_return(true)

    allowed = allow_retry?

    expect(allowed).to be(false)
    expect(retry_budget).not_to have_received(:consume!)
  end

  it 'returns false and emits debug message when retry budget is exhausted' do
    allow(retry_policy).to receive(:retry_allowed?).and_return(true)
    allow(retry_budget).to receive(:consume!).and_return(false)

    allowed = allow_retry?(example_id: 'spec-id')

    expect(allowed).to be(false)
    expect(debug_messages).to include('retry budget exhausted for spec-id')
  end

  it 'returns true when retries are available and policy allows' do
    allow(retry_policy).to receive(:retry_allowed?).and_return(true)
    allow(retry_budget).to receive(:consume!).and_return(true)

    allowed = allow_retry?

    expect(allowed).to be(true)
    expect(debug_messages).to be_empty
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
end
