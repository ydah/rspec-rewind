# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RSpec::Rewind::RetryDelayResolver do
  let(:example) { instance_double(RSpec::Core::Example) }

  def build_resolver(metadata: {}, configure: nil)
    configuration = RSpec::Rewind::Configuration.new
    configure&.call(configuration)
    described_class.new(configuration: configuration, metadata: metadata, example: example)
  end

  it 'uses explicit wait over metadata wait and backoff' do
    resolver = build_resolver(
      metadata: { rewind_wait: 0.1, rewind_backoff: ->(**_) { 0.2 } },
      configure: ->(config) { config.backoff = 0.3 }
    )

    delay = resolver.resolve(retry_number: 1, backoff: ->(**_) { 0.4 }, wait: 0.05, exception: RuntimeError.new('x'))

    expect(delay).to eq(0.05)
  end

  it 'uses callable strategy when wait is not provided' do
    resolver = build_resolver

    delay = resolver.resolve(
      retry_number: 2,
      backoff: ->(retry_number:, example:, exception:) { retry_number == 2 && example && exception ? 0.25 : 0.0 },
      wait: nil,
      exception: RuntimeError.new('x')
    )

    expect(delay).to eq(0.25)
  end

  it 'passes delay context when the strategy accepts it' do
    resolver = build_resolver(metadata: { rewind: 3 })
    seen_context = nil

    delay = resolver.resolve(
      retry_number: 2,
      backoff: lambda { |retry_number:, context:, **_|
        seen_context = context
        retry_number == context.retry_number ? 0.25 : 0.0
      },
      wait: nil,
      exception: RuntimeError.new('x'),
      resolved_retries: 3,
      previous_sleep_seconds: 0.1,
      failure_fingerprint: 'fingerprint'
    )

    expect(delay).to eq(0.25)
    expect(seen_context).to have_attributes(
      resolved_retries: 3,
      previous_sleep_seconds: 0.1,
      failure_fingerprint: 'fingerprint'
    )
  end

  it 'raises for non-callable, non-numeric strategy' do
    resolver = build_resolver(configure: ->(config) { config.backoff = 0.3 })

    expect do
      resolver.resolve(retry_number: 1, backoff: :invalid, wait: nil, exception: RuntimeError.new('x'))
    end.to raise_error(ArgumentError, /backoff must be a non-negative numeric value or callable/)
  end

  it 'raises when resolved delay is invalid' do
    resolver = build_resolver

    expect do
      resolver.resolve(retry_number: 1, backoff: ->(**_) { :bad }, wait: nil, exception: RuntimeError.new('x'))
    end.to raise_error(ArgumentError, /delay must be numeric/)
  end
end
