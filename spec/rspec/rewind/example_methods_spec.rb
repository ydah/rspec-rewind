# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RSpec::Rewind::ExampleMethods do
  let(:dummy_class) do
    Class.new do
      include RSpec::Rewind::ExampleMethods
    end
  end

  let(:dummy_example) { dummy_class.new }
  let(:configuration) { RSpec::Rewind::Configuration.new }
  let(:runner) { instance_spy(RSpec::Rewind::Runner) }
  let(:rewind_options) do
    {
      'retry' => 2,
      'backoff' => :exp,
      'wait' => 0.1,
      'retry_on' => [RuntimeError],
      'skip_retry_on' => [IOError],
      'retry_if' => ->(_exception, _example) { true }
    }
  end

  before do
    allow(RSpec::Rewind).to receive(:configuration).and_return(configuration)
    allow(RSpec::Rewind::Runner).to receive(:new).and_return(runner)
  end

  it 'delegates to Runner with normalized options' do
    dummy_example.run_with_rewind(rewind_options)

    expect(RSpec::Rewind::Runner).to have_received(:new)
      .with(example: dummy_example, configuration: configuration)
    expect(runner).to have_received(:run).with(
      retries: 2,
      backoff: :exp,
      wait: 0.1,
      retry_on: [RuntimeError],
      skip_retry_on: [IOError],
      retry_if: kind_of(Proc)
    )
  end

  it 'passes empty options to Runner' do
    dummy_example.run_with_rewind

    expect(runner).to have_received(:run).with(no_args)
  end
end
