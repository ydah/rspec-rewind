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
        'description' => 'sometimes fails'
      )
    end
  end

  it 'creates directories when path is nested' do
    with_tmp_report_path('nested', 'flaky.jsonl') do |path|
      described_class.new(path).record(event)
      expect(File).to exist(path)
    end
  end

  def with_tmp_report_path(*segments)
    Dir.mktmpdir do |dir|
      yield File.join(dir, *segments)
    end
  end
end
