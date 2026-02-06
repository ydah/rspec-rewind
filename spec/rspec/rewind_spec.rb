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

  it 'executes rewind-enabled examples through installed hook', rewind: 0 do
    expect(described_class.configuration).to be_a(RSpec::Rewind::Configuration)
  end
end
