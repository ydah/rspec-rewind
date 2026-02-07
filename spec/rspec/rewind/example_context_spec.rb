# frozen_string_literal: true

require 'spec_helper'
require_relative 'runner_support'

RSpec.describe RSpec::Rewind::ExampleContext do
  include RunnerSpecSupport

  it 'uses wrapped example when available' do
    nested_example = RunnerSpecSupport::FakeExample.new(outcomes: [nil], metadata: { rewind: 1 })
    wrapper = Object.new
    wrapper.define_singleton_method(:example) { nested_example }

    context = described_class.new(example: wrapper)

    expect(context.source).to be(nested_example)
    expect(context.metadata).to eq(rewind: 1)
    expect(context.id).to eq(nested_example.id)
  end

  it 'falls back to the given example when wrapper is not present' do
    example = RunnerSpecSupport::FakeExample.new(outcomes: [nil], metadata: { rewind: 2 })
    context = described_class.new(example: example)

    expect(context.source).to be(example)
    expect(context.metadata).to eq(rewind: 2)
    expect(context.id).to eq(example.id)
  end

  it 'returns defaults when metadata and id are unavailable' do
    object = Object.new
    context = described_class.new(example: object)

    expect(context.metadata).to eq({})
    expect(context.id).to eq('unknown')
  end
end
