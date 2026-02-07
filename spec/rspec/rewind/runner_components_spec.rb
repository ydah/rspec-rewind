# frozen_string_literal: true

require 'spec_helper'
require_relative 'runner_support'

RSpec.describe RSpec::Rewind::RunnerComponents do
  include RunnerSpecSupport

  it 'builds all collaborators for runner orchestration' do
    configuration = RSpec::Rewind::Configuration.new
    example = RunnerSpecSupport::FakeExample.new(outcomes: [nil], metadata: { rewind: 1 })
    context = RSpec::Rewind::ExampleContext.new(example: example)

    components = described_class.new(
      example: example,
      configuration: configuration,
      context: context,
      debug: ->(_message) {},
      reporter_message: ->(_message) {}
    )

    expect(components.retry_count_resolver).to be_a(RSpec::Rewind::RetryCountResolver)
    expect(components.attempt_runner).to be_a(RSpec::Rewind::AttemptRunner)
    expect(components.retry_gate).to be_a(RSpec::Rewind::RetryGate)
    expect(components.retry_transition).to be_a(RSpec::Rewind::RetryTransition)
    expect(components.flaky_transition).to be_a(RSpec::Rewind::FlakyTransition)
  end
end
