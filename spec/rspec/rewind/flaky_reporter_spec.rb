# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "json"

RSpec.describe RSpec::Rewind::FlakyReporter::JsonlReporter do
  it "writes a JSONL entry" do
    Dir.mktmpdir do |dir|
      path = File.join(dir, "flaky.jsonl")
      reporter = described_class.new(path)

      event = RSpec::Rewind::Event.new(
        status: :flaky,
        example_id: "spec/foo_spec.rb[1:1]",
        description: "sometimes fails",
        location: "spec/foo_spec.rb:5",
        attempt: 2,
        retries: 3,
        exception_class: "RuntimeError",
        exception_message: "flaky",
        duration: 0.02,
        sleep_seconds: 0.0,
        timestamp: "2026-02-06T00:00:00Z"
      )

      reporter.record(event)

      line = File.read(path).strip
      payload = JSON.parse(line)

      expect(payload["status"]).to eq("flaky")
      expect(payload["attempt"]).to eq(2)
      expect(payload["description"]).to eq("sometimes fails")
    end
  end

  it "creates directories when path is nested" do
    Dir.mktmpdir do |dir|
      path = File.join(dir, "nested", "flaky.jsonl")
      reporter = described_class.new(path)

      event = RSpec::Rewind::Event.new(
        status: :flaky,
        example_id: "spec/foo_spec.rb[1:1]",
        description: "sometimes fails",
        location: "spec/foo_spec.rb:5",
        attempt: 2,
        retries: 3,
        exception_class: "RuntimeError",
        exception_message: "flaky",
        duration: 0.02,
        sleep_seconds: 0.0,
        timestamp: "2026-02-06T00:00:00Z"
      )

      reporter.record(event)

      expect(File).to exist(path)
    end
  end
end
