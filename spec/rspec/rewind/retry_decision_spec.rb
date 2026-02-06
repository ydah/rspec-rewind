# frozen_string_literal: true

require "spec_helper"

RSpec.describe RSpec::Rewind::RetryDecision do
  let(:example) { double("example") }

  it "retries when exception matches retry_on" do
    decision = described_class.new(
      exception: StandardError.new("boom"),
      example: example,
      retry_on: [StandardError],
      skip_retry_on: [],
      retry_if: nil
    )

    expect(decision.retry?).to be(true)
  end

  it "does not retry when exception matches skip list" do
    decision = described_class.new(
      exception: RuntimeError.new("fatal"),
      example: example,
      retry_on: [RuntimeError],
      skip_retry_on: [/fatal/],
      retry_if: nil
    )

    expect(decision.retry?).to be(false)
  end

  it "evaluates retry_if predicate" do
    decision = described_class.new(
      exception: RuntimeError.new("temporary"),
      example: example,
      retry_on: [],
      skip_retry_on: [],
      retry_if: ->(_exception, _example) { false }
    )

    expect(decision.retry?).to be(false)
  end

  it "supports callable matchers in retry_on" do
    decision = described_class.new(
      exception: RuntimeError.new("temporary outage"),
      example: example,
      retry_on: [->(exception) { exception.message.include?("outage") }],
      skip_retry_on: [],
      retry_if: nil
    )

    expect(decision.retry?).to be(true)
  end

  it "treats matcher errors as non-match" do
    decision = described_class.new(
      exception: RuntimeError.new("boom"),
      example: example,
      retry_on: [->(_exception) { raise "bad matcher" }],
      skip_retry_on: [],
      retry_if: nil
    )

    expect(decision.retry?).to be(false)
  end
end
