# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RSpec::Rewind::RetryCountResolver do
  def build_resolver(metadata: {}, configure: nil)
    configuration = RSpec::Rewind::Configuration.new
    configure&.call(configuration)
    described_class.new(configuration: configuration, metadata: metadata)
  end

  it 'uses environment retries before explicit retries' do
    original = ENV.fetch('RSPEC_REWIND_RETRIES', nil)
    ENV['RSPEC_REWIND_RETRIES'] = '0'

    resolver = build_resolver(metadata: { rewind: 3 })

    expect(resolver.resolve(explicit_retries: 2)).to eq(0)
  ensure
    ENV['RSPEC_REWIND_RETRIES'] = original
  end

  it 'treats false as zero and true as no override' do
    resolver = build_resolver(metadata: { rewind: true }, configure: ->(config) { config.default_retries = 2 })

    expect(resolver.resolve(explicit_retries: false)).to eq(0)
    expect(resolver.resolve(explicit_retries: true)).to eq(2)
  end

  it 'ignores retry metadata key and uses default retries' do
    resolver = build_resolver(metadata: { retry: 0 }, configure: ->(config) { config.default_retries = 2 })

    expect(resolver.resolve(explicit_retries: nil)).to eq(2)
  end

  it 'raises for invalid environment retries' do
    original = ENV.fetch('RSPEC_REWIND_RETRIES', nil)
    ENV['RSPEC_REWIND_RETRIES'] = 'invalid'

    resolver = build_resolver

    expect do
      resolver.resolve(explicit_retries: nil)
    end.to raise_error(ArgumentError, /RSPEC_REWIND_RETRIES must be a non-negative integer/)
  ensure
    ENV['RSPEC_REWIND_RETRIES'] = original
  end
end
