# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RSpec::Rewind::Backoff do
  describe '.fixed' do
    it 'returns the same delay for every retry' do
      strategy = described_class.fixed(0.25)

      expect(strategy.call(retry_number: 1)).to eq(0.25)
      expect(strategy.call(retry_number: 3)).to eq(0.25)
    end

    it 'raises when seconds is not numeric' do
      expect { described_class.fixed('fast') }.to raise_error(ArgumentError, /seconds must be a numeric value/)
    end
  end

  describe '.linear' do
    it 'grows linearly with retry number' do
      strategy = described_class.linear(step: 0.2)

      expect(strategy.call(retry_number: 1)).to eq(0.2)
      expect(strategy.call(retry_number: 3)).to be_within(0.0001).of(0.6)
    end

    it 'applies a max cap' do
      strategy = described_class.linear(step: 1.5, max: 2.0)

      expect(strategy.call(retry_number: 2)).to eq(2.0)
      expect(strategy.call(retry_number: 10)).to eq(2.0)
    end

    it 'raises when step is negative' do
      expect { described_class.linear(step: -0.1) }.to raise_error(ArgumentError, /step must be >= 0/)
    end
  end

  describe '.exponential' do
    it 'grows exponentially' do
      strategy = described_class.exponential(base: 0.1, factor: 2)

      expect(strategy.call(retry_number: 1)).to eq(0.1)
      expect(strategy.call(retry_number: 2)).to eq(0.2)
      expect(strategy.call(retry_number: 3)).to eq(0.4)
    end

    it 'supports jitter' do
      allow(Kernel).to receive(:rand).and_return(0.5)

      strategy = described_class.exponential(base: 1.0, jitter: 0.2)
      delay = strategy.call(retry_number: 2)

      expect(delay).to be_between(1.6, 2.4)
    end

    it 'raises when jitter is negative' do
      expect do
        described_class.exponential(base: 0.1, jitter: -0.2)
      end.to raise_error(ArgumentError, /jitter must be >= 0/)
    end
  end
end
