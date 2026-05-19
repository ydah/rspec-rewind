# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RSpec::Rewind do
  around do |example|
    described_class.reset_configuration!
    example.run
  ensure
    described_class.reset_configuration!
  end

  describe '.configuration' do
    it 'memoizes the configuration object' do
      first = described_class.configuration
      second = described_class.configuration

      expect(first).to be(second)
    end
  end

  describe '.configure' do
    it 'yields and mutates global configuration' do
      yielded = nil

      described_class.configure do |config|
        yielded = config
        config.default_retries = 1
      end

      expect(yielded).to be(described_class.configuration)
      expect(described_class.configuration.default_retries).to eq(1)
    end
  end

  describe '.installed?' do
    it 'reports installed hook state' do
      expect(described_class.installed?).to be(true)
      expect(described_class.install!).to be(false)
    end

    it 'keeps installed hook state after configuration reset' do
      described_class.reset_configuration!

      expect(described_class.installed?).to be(true)
      expect(described_class.configuration).to be_a(RSpec::Rewind::Configuration)
    end
  end

  describe '.prepare_suite!' do
    it 'resets retry summary and can freeze configuration' do
      described_class.configuration.retry_summary.record(RSpec::Rewind::Event.new(status: :flaky))
      described_class.configuration.freeze_configuration_at_suite_start = true

      described_class.prepare_suite!

      expect(described_class.configuration.retry_summary.flaky_examples).to eq(0)
      expect(described_class.configuration).to be_frozen
    end
  end

  describe '.enforce_flaky_threshold!' do
    it 'raises when fail_on_flaky is enabled and flaky examples were observed' do
      described_class.configuration.fail_on_flaky = true
      described_class.configuration.retry_summary.record(RSpec::Rewind::Event.new(status: :flaky))

      expect do
        described_class.enforce_flaky_threshold!
      end.to raise_error(RSpec::Rewind::FlakyThresholdExceeded, /1 flaky/)
    end

    it 'raises when max_flaky_examples is exceeded' do
      described_class.configuration.max_flaky_examples = 0
      described_class.configuration.retry_summary.record(RSpec::Rewind::Event.new(status: :flaky))

      expect do
        described_class.enforce_flaky_threshold!
      end.to raise_error(RSpec::Rewind::FlakyThresholdExceeded)
    end
  end

  describe '.warn_on_retry_gem_conflict' do
    it 'warns when another retry integration is loaded' do
      stub_const('RSpec::Retry', Module.new)
      allow(described_class).to receive(:warn)

      described_class.warn_on_retry_gem_conflict

      expect(described_class).to have_received(:warn).with(include('rspec-retry appears to be loaded'))
    end
  end

  it 'executes rewind-enabled examples through installed hook', rewind: 0 do
    expect(described_class.configuration).to be_a(RSpec::Rewind::Configuration)
  end
end
