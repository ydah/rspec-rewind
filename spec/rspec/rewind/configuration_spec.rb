# frozen_string_literal: true

require "spec_helper"

RSpec.describe RSpec::Rewind::Configuration do
  describe "defaults" do
    it "initializes with conservative defaults" do
      config = described_class.new

      expect(config.default_retries).to eq(0)
      expect(config.backoff).to respond_to(:call)
      expect(config.retry_on).to eq([])
      expect(config.skip_retry_on).to eq([])
      expect(config.retry_if).to be_nil
      expect(config.retry_callback).to be_nil
      expect(config.flaky_callback).to be_nil
      expect(config.verbose).to be(false)
      expect(config.display_retry_failure_messages).to be(false)
      expect(config.clear_lets_on_failure).to be(true)
      expect(config.retry_budget).to be_a(RSpec::Rewind::RetryBudget)
      expect(config.flaky_reporter).to be_a(RSpec::Rewind::FlakyReporter::NullReporter)
    end
  end

  describe "#retry_budget=" do
    it "accepts a numeric limit" do
      config = described_class.new

      config.retry_budget = 3

      expect(config.retry_budget.limit).to eq(3)
    end

    it "accepts a RetryBudget instance" do
      config = described_class.new
      budget = RSpec::Rewind::RetryBudget.new(7)

      config.retry_budget = budget

      expect(config.retry_budget).to be(budget)
    end
  end

  describe "flaky reporter configuration" do
    it "switches reporter by flaky_report_path" do
      config = described_class.new

      config.flaky_report_path = "tmp/flaky.jsonl"
      expect(config.flaky_reporter).to be_a(RSpec::Rewind::FlakyReporter::JsonlReporter)

      config.flaky_report_path = nil
      expect(config.flaky_reporter).to be_a(RSpec::Rewind::FlakyReporter::NullReporter)
    end

    it "falls back to null reporter when flaky_reporter is nil" do
      config = described_class.new

      config.flaky_reporter = nil

      expect(config.flaky_reporter).to be_a(RSpec::Rewind::FlakyReporter::NullReporter)
    end
  end
end
