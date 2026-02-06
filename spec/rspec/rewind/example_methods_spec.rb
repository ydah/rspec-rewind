# frozen_string_literal: true

require "spec_helper"

RSpec.describe RSpec::Rewind::ExampleMethods do
  let(:dummy_class) do
    Class.new do
      include RSpec::Rewind::ExampleMethods
    end
  end

  let(:dummy_example) { dummy_class.new }
  let(:configuration) { RSpec::Rewind::Configuration.new }

  it "delegates to Runner with normalized options" do
    runner = instance_double(RSpec::Rewind::Runner)

    allow(RSpec::Rewind).to receive(:configuration).and_return(configuration)
    expect(RSpec::Rewind::Runner).to receive(:new)
      .with(example: dummy_example, configuration: configuration)
      .and_return(runner)

    expect(runner).to receive(:run).with(
      retries: 2,
      backoff: :exp,
      wait: 0.1,
      retry_on: [RuntimeError],
      skip_retry_on: [IOError],
      retry_if: kind_of(Proc)
    )

    dummy_example.run_with_rewind(
      "retry" => 2,
      "backoff" => :exp,
      "wait" => 0.1,
      "retry_on" => [RuntimeError],
      "skip_retry_on" => [IOError],
      "retry_if" => ->(_exception, _example) { true }
    )
  end

  it "passes empty options to Runner" do
    runner = instance_double(RSpec::Rewind::Runner)

    allow(RSpec::Rewind).to receive(:configuration).and_return(configuration)
    allow(RSpec::Rewind::Runner).to receive(:new)
      .with(example: dummy_example, configuration: configuration)
      .and_return(runner)

    expect(runner).to receive(:run).with(no_args)

    dummy_example.run_with_rewind
  end
end
