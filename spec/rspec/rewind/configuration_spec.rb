# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RSpec::Rewind::Configuration do
  describe 'defaults' do
    it 'initializes with conservative defaults' do
      config = described_class.new

      expect(config).to have_attributes(
        default_retries: 0,
        retry_on: [],
        skip_retry_on: [],
        retry_if: nil,
        retry_callback: nil,
        flaky_callback: nil,
        verbose: false,
        display_retry_failure_messages: false,
        clear_lets_on_failure: true
      )
      expect(config.backoff).to respond_to(:call)
      expect(config.retry_budget).to be_a(RSpec::Rewind::RetryBudget)
      expect(config.flaky_reporter).to be_a(RSpec::Rewind::FlakyReporter::NullReporter)
    end
  end

  describe '#retry_budget=' do
    it 'accepts a numeric limit' do
      config = described_class.new

      config.retry_budget = 3

      expect(config.retry_budget.limit).to eq(3)
    end

    it 'accepts a RetryBudget instance' do
      config = described_class.new
      budget = RSpec::Rewind::RetryBudget.new(7)

      config.retry_budget = budget

      expect(config.retry_budget).to be(budget)
    end
  end

  describe 'validation' do
    it 'raises when default_retries is invalid' do
      config = described_class.new

      expect do
        config.default_retries = -1
      end.to raise_error(ArgumentError, /default_retries must be >= 0/)

      expect do
        config.default_retries = 'many'
      end.to raise_error(ArgumentError, /default_retries must be a non-negative integer/)
    end

    it 'raises when backoff is invalid' do
      config = described_class.new

      expect do
        config.backoff = -0.1
      end.to raise_error(ArgumentError, /backoff must be >= 0/)

      expect do
        config.backoff = :fast
      end.to raise_error(ArgumentError, /backoff must be a non-negative numeric value or callable/)
    end

    it 'accepts numeric backoff values' do
      config = described_class.new

      config.backoff = 0.25

      expect(config.backoff).to eq(0.25)
    end

    it 'raises when callbacks are not callable' do
      config = described_class.new

      expect do
        config.retry_if = :predicate
      end.to raise_error(ArgumentError, /retry_if must be nil or callable/)

      expect do
        config.retry_callback = :callback
      end.to raise_error(ArgumentError, /retry_callback must be nil or callable/)

      expect do
        config.flaky_callback = :callback
      end.to raise_error(ArgumentError, /flaky_callback must be nil or callable/)
    end

    it 'raises when boolean settings are not booleans' do
      config = described_class.new

      expect do
        config.verbose = nil
      end.to raise_error(ArgumentError, /verbose must be true or false/)

      expect do
        config.display_retry_failure_messages = 'yes'
      end.to raise_error(ArgumentError, /display_retry_failure_messages must be true or false/)

      expect do
        config.clear_lets_on_failure = 1
      end.to raise_error(ArgumentError, /clear_lets_on_failure must be true or false/)
    end
  end

  describe 'flaky reporter configuration' do
    it 'switches reporter by flaky_report_path' do
      config = described_class.new

      config.flaky_report_path = 'tmp/flaky.jsonl'
      expect(config.flaky_reporter).to be_a(RSpec::Rewind::FlakyReporter::JsonlReporter)

      config.flaky_report_path = nil
      expect(config.flaky_reporter).to be_a(RSpec::Rewind::FlakyReporter::NullReporter)
    end

    it 'falls back to null reporter when flaky_reporter is nil' do
      config = described_class.new

      config.flaky_reporter = nil

      expect(config.flaky_reporter).to be_a(RSpec::Rewind::FlakyReporter::NullReporter)
    end
  end
end
