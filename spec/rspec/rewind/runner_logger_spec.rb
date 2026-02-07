# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RSpec::Rewind::RunnerLogger do
  it 'writes message through rspec reporter when available' do
    configuration = RSpec::Rewind::Configuration.new
    warn_calls = []
    logger = described_class.new(configuration: configuration, warn_output: ->(message) { warn_calls << message })
    allow(RSpec.configuration.reporter).to receive(:message)

    logger.reporter_message('[rspec-rewind] hello')

    expect(RSpec.configuration.reporter).to have_received(:message).with('[rspec-rewind] hello')
    expect(warn_calls).to be_empty
  end

  it 'falls back to warn output when reporter messaging fails' do
    configuration = RSpec::Rewind::Configuration.new
    warn_calls = []
    logger = described_class.new(configuration: configuration, warn_output: ->(message) { warn_calls << message })
    allow(RSpec.configuration.reporter).to receive(:message).and_raise(StandardError, 'boom')

    logger.reporter_message('[rspec-rewind] hello')

    expect(warn_calls).to eq(['[rspec-rewind] hello'])
  end

  it 'emits prefixed debug message only when verbose is enabled' do
    configuration = RSpec::Rewind::Configuration.new
    warn_calls = []
    logger = described_class.new(configuration: configuration, warn_output: ->(message) { warn_calls << message })
    allow(RSpec.configuration.reporter).to receive(:message)

    logger.debug('first')
    configuration.verbose = true
    logger.debug('second')

    expect(RSpec.configuration.reporter).to have_received(:message).with('[rspec-rewind] second')
    expect(warn_calls).to be_empty
  end
end
