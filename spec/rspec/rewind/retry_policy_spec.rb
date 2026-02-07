# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RSpec::Rewind::RetryPolicy do
  let(:example) { instance_double(RSpec::Core::Example) }

  def build_policy(metadata: {}, configure: nil)
    configuration = RSpec::Rewind::Configuration.new
    configure&.call(configuration)
    described_class.new(example: example, configuration: configuration, metadata: metadata)
  end

  it 'uses config, metadata, and explicit retry_on matchers together' do
    policy = build_policy(
      metadata: { rewind_retry_on: [IOError] },
      configure: ->(config) { config.retry_on = [RuntimeError] }
    )

    allowed = policy.retry_allowed?(
      exception: StandardError.new('temporary failure'),
      retry_on: [/temporary/],
      skip_retry_on: nil,
      retry_if: nil
    )

    expect(allowed).to be(true)
  end

  it 'uses rewind_skip_retry_on metadata key' do
    policy = build_policy(metadata: { rewind_skip_retry_on: [RuntimeError] })

    allowed = policy.retry_allowed?(
      exception: RuntimeError.new('boom'),
      retry_on: [RuntimeError],
      skip_retry_on: nil,
      retry_if: nil
    )

    expect(allowed).to be(false)
  end

  it 'uses metadata retry_if before configuration retry_if' do
    policy = build_policy(
      metadata: { rewind_if: ->(_exception, _example) { false } },
      configure: ->(config) { config.retry_if = ->(_exception, _example) { true } }
    )

    allowed = policy.retry_allowed?(
      exception: RuntimeError.new('boom'),
      retry_on: [RuntimeError],
      skip_retry_on: nil,
      retry_if: nil
    )

    expect(allowed).to be(false)
  end

  it 'uses explicit retry_if before metadata and configuration' do
    policy = build_policy(
      metadata: { rewind_if: ->(_exception, _example) { false } },
      configure: ->(config) { config.retry_if = ->(_exception, _example) { false } }
    )

    allowed = policy.retry_allowed?(
      exception: RuntimeError.new('boom'),
      retry_on: [RuntimeError],
      skip_retry_on: nil,
      retry_if: ->(_exception, _example) { true }
    )

    expect(allowed).to be(true)
  end

  it 'raises when explicit retry_on contains unsupported matcher types' do
    policy = build_policy

    expect do
      policy.retry_allowed?(
        exception: RuntimeError.new('boom'),
        retry_on: [:invalid],
        skip_retry_on: nil,
        retry_if: nil
      )
    end.to raise_error(ArgumentError, /retry_on entries must be Module, Regexp, or callable/)
  end

  it 'raises when rewind_skip_retry_on metadata contains unsupported matcher types' do
    policy = build_policy(metadata: { rewind_skip_retry_on: [123] })

    expect do
      policy.retry_allowed?(
        exception: RuntimeError.new('boom'),
        retry_on: [RuntimeError],
        skip_retry_on: nil,
        retry_if: nil
      )
    end.to raise_error(ArgumentError, /rewind_skip_retry_on entries must be Module, Regexp, or callable/)
  end
end
