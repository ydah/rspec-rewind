# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RSpec::Rewind::RetryBudget do
  it 'allows unlimited retries when limit is nil' do
    budget = described_class.new(nil)

    3.times { expect(budget.consume!).to be(true) }
    expect(budget.unlimited?).to be(true)
    expect(budget.remaining).to eq(Float::INFINITY)
  end

  it 'stops consuming retries once the budget is exhausted' do
    budget = described_class.new(2)

    expect(budget.consume!).to be(true)
    expect(budget.consume!).to be(true)
    expect(budget.consume!).to be(false)
    expect(budget.used).to eq(2)
    expect(budget.remaining).to eq(0)
  end

  it 'raises on invalid limit' do
    expect do
      described_class.new('many')
    end.to raise_error(ArgumentError, /retry budget must be nil or a non-negative integer/)
    expect { described_class.new(-1) }.to raise_error(ArgumentError, /retry budget must be >= 0/)
  end
end
