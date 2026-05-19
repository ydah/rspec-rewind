# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'json'

RSpec.describe RSpec::Rewind::FlakyReporter::JsonlReporter do
  let(:event) do
    RSpec::Rewind::Event.new(
      schema_version: 1,
      status: :flaky,
      retry_reason: nil,
      example_id: 'spec/foo_spec.rb[1:1]',
      description: 'sometimes fails',
      location: 'spec/foo_spec.rb:5',
      attempt: 2,
      retries: 3,
      exception_class: 'RuntimeError',
      exception_message: 'flaky',
      duration: 0.02,
      sleep_seconds: 0.0,
      timestamp: '2026-02-06T00:00:00Z'
    )
  end

  it 'writes a JSONL entry' do
    with_tmp_report_path('flaky.jsonl') do |path|
      described_class.new(path).record(event)

      payload = JSON.parse(File.read(path))

      expect(payload).to include(
        'schema_version' => 1,
        'status' => 'flaky',
        'retry_reason' => nil,
        'attempt' => 2,
        'description' => 'sometimes fails',
        'max_attempts' => nil
      )
    end
  end

  it 'creates directories when path is nested' do
    with_tmp_report_path('nested', 'flaky.jsonl') do |path|
      described_class.new(path).record(event)
      expect(File).to exist(path)
    end
  end

  it 'appends safely from multiple processes' do
    skip 'fork is not available on this platform' unless Process.respond_to?(:fork)

    with_tmp_report_path('parallel.jsonl') do |path|
      pids = 3.times.map do
        fork do
          described_class.new(path).record(event)
        end
      end
      pids.each { |pid| Process.wait(pid) }

      lines = File.readlines(path)

      expect(lines.size).to eq(3)
      expect(lines.map { |line| JSON.parse(line).fetch('status') }).to all(eq('flaky'))
    end
  end

  it 'shares reporter lifecycle methods with the null reporter' do
    reporter = RSpec::Rewind::FlakyReporter.null

    expect { reporter.flush }.not_to raise_error
    expect { reporter.close }.not_to raise_error
  end

  def with_tmp_report_path(*segments)
    Dir.mktmpdir do |dir|
      yield File.join(dir, *segments)
    end
  end
end
