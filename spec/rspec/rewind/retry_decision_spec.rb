# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RSpec::Rewind::RetryDecision do
  let(:example) { instance_double(RSpec::Core::Example) }

  it 'retries when exception matches retry_on' do
    decision = described_class.new(
      exception: StandardError.new('boom'),
      example: example,
      retry_on: [StandardError],
      skip_retry_on: [],
      retry_if: nil
    )

    expect(decision.retry?).to be(true)
  end

  it 'does not retry when exception matches skip list' do
    decision = described_class.new(
      exception: RuntimeError.new('fatal'),
      example: example,
      retry_on: [RuntimeError],
      skip_retry_on: [/fatal/],
      retry_if: nil
    )

    expect(decision.retry?).to be(false)
  end

  it 'evaluates retry_if predicate' do
    decision = described_class.new(
      exception: RuntimeError.new('temporary'),
      example: example,
      retry_on: [],
      skip_retry_on: [],
      retry_if: ->(_exception, _example) { false }
    )

    expect(decision.retry?).to be(false)
  end

  it 'supports callable matchers in retry_on' do
    decision = described_class.new(
      exception: RuntimeError.new('temporary outage'),
      example: example,
      retry_on: [->(exception) { exception.message.include?('outage') }],
      skip_retry_on: [],
      retry_if: nil
    )

    expect(decision.retry?).to be(true)
  end

  it 'passes example context to two-argument callable matchers' do
    decision = described_class.new(
      exception: RuntimeError.new('temporary outage'),
      example: example,
      retry_on: [->(exception, ex) { exception.message.include?('outage') && ex.equal?(example) }],
      skip_retry_on: [],
      retry_if: nil
    )

    expect(decision.retry?).to be(true)
  end

  it 'supports one-argument retry_if predicates' do
    decision = described_class.new(
      exception: RuntimeError.new('temporary'),
      example: example,
      retry_on: [],
      skip_retry_on: [],
      retry_if: ->(exception) { exception.message == 'temporary' }
    )

    expect(decision.retry?).to be(true)
  end

  it 'supports variadic retry_if predicates' do
    decision = described_class.new(
      exception: RuntimeError.new('temporary'),
      example: example,
      retry_on: [],
      skip_retry_on: [],
      retry_if: proc { |*args| args[0].message == 'temporary' && args[1].equal?(example) }
    )

    expect(decision.retry?).to be(true)
  end

  it 'supports callable objects that do not implement arity' do
    seen = nil
    matcher = Object.new
    matcher.define_singleton_method(:call) do |exception, ex|
      seen = [exception, ex]
      true
    end

    decision = described_class.new(
      exception: RuntimeError.new('temporary'),
      example: example,
      retry_on: [matcher],
      skip_retry_on: [],
      retry_if: nil
    )

    expect(decision.retry?).to be(true)
    expect(seen.last).to be(example)
  end

  it 'treats matcher errors as non-match' do
    decision = described_class.new(
      exception: RuntimeError.new('boom'),
      example: example,
      retry_on: [->(_exception) { raise 'bad matcher' }],
      skip_retry_on: [],
      retry_if: nil
    )

    expect(decision.retry?).to be(false)
  end

  it 'exposes rejection reason and matcher error' do
    matcher = ->(_exception) { raise 'bad matcher' }
    result = build_decision(exception: RuntimeError.new('boom'), retry_on: [matcher]).decision

    expect(result).to have_attributes(
      allowed?: false,
      reason: :retry_on_not_matched,
      matcher_error: include('RuntimeError: bad matcher')
    )
  end

  it 'records matched matcher descriptions' do
    matcher = Class.new do
      def description
        'temporary gateway'
      end

      def call(exception)
        exception.message.include?('temporary')
      end
    end.new

    result = build_decision(retry_on: [matcher]).decision

    expect(result.matched_retry_on).to eq('temporary gateway')
  end

  it 'can reject by retry_on default policy' do
    result = build_decision(retry_on_default: :none).decision

    expect(result).to have_attributes(allowed?: false, reason: :retry_on_default_rejected)
  end

  it 'passes retry context to three-argument predicates' do
    context = RSpec::Rewind::RetryContext.new(attempt: 2, retries: 3)
    decision = build_decision(
      retry_if: ->(_exception, _example, retry_context) { retry_context.attempt == 2 },
      context: context
    )

    expect(decision.retry?).to be(true)
  end

  it 'can raise on unsupported callable arity in strict mode' do
    decision = build_decision(
      retry_if: ->(_exception, _example, _context, _extra) { true },
      strict_callable_arity: true
    )

    expect { decision.retry? }.to raise_error(ArgumentError, /maximum supported/)
  end

  def build_decision(
    exception: RuntimeError.new('temporary'),
    retry_on: [],
    skip_retry_on: [],
    retry_if: nil,
    retry_on_default: :all,
    context: nil,
    strict_callable_arity: false
  )
    described_class.new(
      exception: exception,
      example: example,
      retry_on: retry_on,
      skip_retry_on: skip_retry_on,
      retry_if: retry_if,
      retry_on_default: retry_on_default,
      context: context,
      strict_callable_arity: strict_callable_arity
    )
  end
end
