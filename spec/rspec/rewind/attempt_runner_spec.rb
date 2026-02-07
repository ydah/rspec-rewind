# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RSpec::Rewind::AttemptRunner do
  subject(:attempt_runner) { described_class.new }

  it 'captures exception from exception source when run completes' do
    run_target = Object.new
    def run_target.run; end

    expected_exception = RuntimeError.new('stored failure')
    exception_source = Object.new
    exception_source.define_singleton_method(:exception) { expected_exception }

    exception, duration, raised = attempt_runner.run(run_target: run_target, exception_source: exception_source)

    expect(exception).to eq(expected_exception)
    expect(duration).to be >= 0.0
    expect(raised).to be(false)
  end

  it 'captures raised exception as retry target' do
    run_target = Object.new
    run_target.define_singleton_method(:run) { raise 'boom' }
    exception_source = Object.new

    exception, duration, raised = attempt_runner.run(run_target: run_target, exception_source: exception_source)

    expect(exception).to be_a(RuntimeError)
    expect(exception.message).to eq('boom')
    expect(duration).to be >= 0.0
    expect(raised).to be(true)
  end

  it 'returns nil exception when source does not expose exception reader' do
    run_target = Object.new
    def run_target.run; end

    exception_source = Object.new

    exception, = attempt_runner.run(run_target: run_target, exception_source: exception_source)

    expect(exception).to be_nil
  end

  it 're-raises fatal exceptions' do
    run_target = Object.new
    run_target.define_singleton_method(:run) { raise SystemExit, 1 }
    exception_source = Object.new

    expect do
      attempt_runner.run(run_target: run_target, exception_source: exception_source)
    end.to raise_error(SystemExit)
  end
end
