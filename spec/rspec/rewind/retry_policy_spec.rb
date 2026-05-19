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

  it 'can AND-combine configuration, metadata, and explicit retry_if predicates' do
    policy = build_policy(
      metadata: { rewind_if: ->(_exception, _example) { true } },
      configure: lambda do |config|
        config.retry_if_mode = :and
        config.retry_if = ->(_exception, _example) { true }
      end
    )

    allowed = policy.retry_allowed?(
      exception: RuntimeError.new('boom'),
      retry_on: [RuntimeError],
      skip_retry_on: nil,
      retry_if: ->(_exception, _example) { false }
    )

    expect(allowed).to be(false)
  end

  it 'can OR-combine retry_if predicates' do
    policy = build_policy(
      metadata: { rewind_if: ->(_exception, _example) { false } },
      configure: lambda do |config|
        config.retry_if_mode = :or
        config.retry_if = ->(_exception, _example) { false }
      end
    )

    allowed = policy.retry_allowed?(
      exception: RuntimeError.new('boom'),
      retry_on: [RuntimeError],
      skip_retry_on: nil,
      retry_if: ->(_exception, _example) { true }
    )

    expect(allowed).to be(true)
  end

  it 'passes elapsed and sleep totals to retry_if context' do
    policy = build_policy

    decision = policy.decision(
      exception: RuntimeError.new('boom'),
      retry_on: [RuntimeError],
      skip_retry_on: nil,
      retry_if: lambda { |_exception, _example, context|
        context.elapsed_time == 125 && context.sleep_total == 50
      },
      retry_number: 1,
      resolved_retries: 2,
      elapsed_time: 125,
      sleep_total: 50
    )

    expect(decision).to be_allowed
  end

  it 'can override retry_if mode from metadata' do
    policy = build_policy(
      metadata: {
        rewind_if_mode: :and,
        rewind_if: ->(_exception, _example) { true }
      },
      configure: lambda do |config|
        config.retry_if_mode = :or
        config.retry_if = ->(_exception, _example) { false }
      end
    )

    allowed = policy.retry_allowed?(
      exception: RuntimeError.new('boom'),
      retry_on: [RuntimeError],
      skip_retry_on: nil,
      retry_if: nil
    )

    expect(allowed).to be(false)
  end

  it 'can override configured retry_on matchers from metadata' do
    policy = build_policy(
      metadata: { rewind_retry_on_mode: :override, rewind_retry_on: [IOError] },
      configure: ->(config) { config.retry_on = [RuntimeError] }
    )

    allowed = policy.retry_allowed?(
      exception: RuntimeError.new('boom'),
      retry_on: nil,
      skip_retry_on: nil,
      retry_if: nil
    )

    expect(allowed).to be(false)
  end

  it 'can override configured skip_retry_on matchers from metadata' do
    policy = build_policy(
      metadata: { rewind_skip_retry_on_mode: :override },
      configure: ->(config) { config.skip_retry_on = [RuntimeError] }
    )

    allowed = policy.retry_allowed?(
      exception: RuntimeError.new('boom'),
      retry_on: [RuntimeError],
      skip_retry_on: nil,
      retry_if: nil
    )

    expect(allowed).to be(true)
  end

  it 'raises when metadata retry_if mode is invalid' do
    policy = build_policy(metadata: { rewind_if_mode: :xor })

    expect do
      policy.retry_allowed?(
        exception: RuntimeError.new('boom'),
        retry_on: [RuntimeError],
        skip_retry_on: nil,
        retry_if: nil
      )
    end.to raise_error(ArgumentError, /rewind_if_mode must be one of/)
  end

  it 'raises when metadata retry_on mode is invalid' do
    policy = build_policy(metadata: { rewind_retry_on_mode: :replace })

    expect do
      policy.retry_allowed?(
        exception: RuntimeError.new('boom'),
        retry_on: [RuntimeError],
        skip_retry_on: nil,
        retry_if: nil
      )
    end.to raise_error(ArgumentError, /rewind_retry_on_mode must be one of/)
  end

  it 'raises when metadata skip_retry_on mode is invalid' do
    policy = build_policy(metadata: { rewind_skip_retry_on_mode: :replace })

    expect do
      policy.retry_allowed?(
        exception: RuntimeError.new('boom'),
        retry_on: [RuntimeError],
        skip_retry_on: nil,
        retry_if: nil
      )
    end.to raise_error(ArgumentError, /rewind_skip_retry_on_mode must be one of/)
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
