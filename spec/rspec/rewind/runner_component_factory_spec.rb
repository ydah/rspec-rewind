# frozen_string_literal: true

require 'spec_helper'
require_relative 'runner_support'

RSpec.describe RSpec::Rewind::RunnerComponentFactory do
  it 'builds runner components' do
    configuration = RSpec::Rewind::Configuration.new
    example = RunnerSpecSupport::FakeExample.new(outcomes: [nil])
    context = RSpec::Rewind::ExampleContext.new(example: example)
    logger = RSpec::Rewind::RunnerLogger.new(configuration: configuration, warn_output: ->(_message) {})

    components = described_class.new.build(
      example: example,
      configuration: configuration,
      context: context,
      logger: logger
    )

    expect(components).to be_a(RSpec::Rewind::RunnerComponents)
  end
end
