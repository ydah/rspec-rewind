# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RSpec::Rewind::Configuration do
  describe 'defaults' do
    it 'initializes with conservative defaults' do
      config = described_class.new

      expect(config).to have_attributes(
        default_retries: 0,
        retry_on: [],
        skip_retry_on: [],
        retry_if: nil,
        retry_callback: nil,
        flaky_callback: nil,
        not_retried_callback: nil,
        verbose: false,
        display_retry_failure_messages: false,
        display_retry_backtrace_top: false,
        display_retry_summary: false,
        fail_on_flaky: false,
        max_flaky_examples: nil,
        freeze_configuration_at_suite_start: false,
        warn_on_delay_conflict: true,
        detect_retry_gem_conflicts: true,
        clear_lets_on_failure: true,
        reset_failure_policy: :raise,
        retry_if_mode: :override,
        retry_on_default: :all,
        report_retry_events: false,
        strict_callbacks: false,
        strict_callable_arity: false,
        strict_matcher_validation: false,
        metadata_report_keys: [],
        max_retries: nil,
        max_elapsed_time: nil,
        max_total_sleep: nil,
        dry_run: false
      )
      expect(config.backoff).to respond_to(:call)
      expect(config.retry_budget).to be_a(RSpec::Rewind::RetryBudget)
      expect(config.retry_summary).to be_a(RSpec::Rewind::RetrySummary)
      expect(config.flaky_reporter).to be_a(RSpec::Rewind::FlakyReporter::NullReporter)
      expect(config.sleeper).to respond_to(:call)
      expect(config.clock).to respond_to(:call)
    end
  end

  describe '#retry_budget=' do
    it 'accepts a numeric limit' do
      config = described_class.new

      config.retry_budget = 3

      expect(config.retry_budget.limit).to eq(3)
    end

    it 'accepts a RetryBudget instance' do
      config = described_class.new
      budget = RSpec::Rewind::RetryBudget.new(7)

      config.retry_budget = budget

      expect(config.retry_budget).to be(budget)
    end
  end

  describe 'validation' do
    it 'raises when default_retries is invalid' do
      config = described_class.new

      expect do
        config.default_retries = -1
      end.to raise_error(ArgumentError, /default_retries must be >= 0/)

      expect do
        config.default_retries = 'many'
      end.to raise_error(ArgumentError, /default_retries must be a non-negative integer/)
    end

    it 'raises when backoff is invalid' do
      config = described_class.new

      expect do
        config.backoff = -0.1
      end.to raise_error(ArgumentError, /backoff must be >= 0/)

      expect do
        config.backoff = :fast
      end.to raise_error(ArgumentError, /backoff must be a non-negative numeric value or callable/)
    end

    it 'accepts numeric backoff values' do
      config = described_class.new

      config.backoff = 0.25

      expect(config.backoff).to eq(0.25)
    end

    it 'raises when callbacks are not callable' do
      config = described_class.new

      expect do
        config.retry_if = :predicate
      end.to raise_error(ArgumentError, /retry_if must be nil or callable/)

      expect do
        config.retry_callback = :callback
      end.to raise_error(ArgumentError, /retry_callback must be nil or callable/)

      expect do
        config.flaky_callback = :callback
      end.to raise_error(ArgumentError, /flaky_callback must be nil or callable/)

      expect do
        config.not_retried_callback = :callback
      end.to raise_error(ArgumentError, /not_retried_callback must be nil or callable/)
    end

    it 'accepts Module, Regexp, and callable retry matchers' do
      config = described_class.new
      callable = ->(_exception, _example) { true }

      config.retry_on = [RuntimeError, /temporary/, callable]
      config.skip_retry_on = [[IOError], [/fatal/], [callable]]

      expect(config.retry_on).to eq([RuntimeError, /temporary/, callable])
      expect(config.skip_retry_on).to eq([IOError, /fatal/, callable])
    end

    it 'raises when retry_on contains unsupported matcher types' do
      config = described_class.new

      expect do
        config.retry_on = [RuntimeError, :invalid]
      end.to raise_error(ArgumentError, /retry_on entries must be Module, Regexp, or callable/)
    end

    it 'can require Module matchers to be Exception classes' do
      config = described_class.new
      config.strict_matcher_validation = true

      expect do
        config.retry_on = [Enumerable]
      end.to raise_error(ArgumentError, /Exception classes/)

      config.retry_on = [RuntimeError]
      expect(config.retry_on).to eq([RuntimeError])
    end

    it 'raises when skip_retry_on contains unsupported matcher types' do
      config = described_class.new

      expect do
        config.skip_retry_on = [{ matcher: 'invalid' }]
      end.to raise_error(ArgumentError, /skip_retry_on entries must be Module, Regexp, or callable/)
    end

    it 'raises when boolean settings are not booleans' do
      config = described_class.new

      expect do
        config.verbose = nil
      end.to raise_error(ArgumentError, /verbose must be true or false/)

      expect do
        config.display_retry_failure_messages = 'yes'
      end.to raise_error(ArgumentError, /display_retry_failure_messages must be true or false/)

      expect do
        config.clear_lets_on_failure = 1
      end.to raise_error(ArgumentError, /clear_lets_on_failure must be true or false/)
    end

    it 'raises when enum settings are invalid' do
      config = described_class.new

      expect do
        config.retry_if_mode = :xor
      end.to raise_error(ArgumentError, /retry_if_mode must be one of/)

      expect do
        config.retry_on_default = :assertions
      end.to raise_error(ArgumentError, /retry_on_default must be one of/)

      expect do
        config.reset_failure_policy = :ignore
      end.to raise_error(ArgumentError, /reset_failure_policy must be one of/)
    end

    it 'raises when retry ceilings are invalid' do
      config = described_class.new

      expect { config.max_retries = -1 }.to raise_error(ArgumentError, /max_retries must be >= 0/)
      expect { config.max_flaky_examples = -1 }.to raise_error(ArgumentError, /max_flaky_examples must be >= 0/)
      expect { config.max_elapsed_time = -0.1 }.to raise_error(ArgumentError, /max_elapsed_time must be >= 0/)
      expect { config.max_total_sleep = 'slow' }.to raise_error(ArgumentError, /max_total_sleep must be a numeric/)
    end

    it 'raises when retry_summary does not expose the expected interface' do
      config = described_class.new

      expect do
        config.retry_summary = Object.new
      end.to raise_error(ArgumentError, /retry_summary must respond to #record and #reset!/)
    end
  end

  describe 'flaky reporter configuration' do
    it 'switches reporter by flaky_report_path' do
      config = described_class.new

      config.flaky_report_path = 'tmp/flaky.jsonl'
      expect(config.flaky_reporter).to be_a(RSpec::Rewind::FlakyReporter::JsonlReporter)
      expect(config.flaky_report_path).to eq('tmp/flaky.jsonl')

      config.flaky_report_path = nil
      expect(config.flaky_reporter).to be_a(RSpec::Rewind::FlakyReporter::NullReporter)
      expect(config.flaky_report_path).to be_nil
    end

    it 'falls back to null reporter when flaky_reporter is nil' do
      config = described_class.new
      config.flaky_report_path = 'tmp/flaky.jsonl'

      config.flaky_reporter = nil

      expect(config.flaky_reporter).to be_a(RSpec::Rewind::FlakyReporter::NullReporter)
      expect(config.flaky_report_path).to be_nil
    end

    it 'keeps flaky_report_path aligned with assigned reporters' do
      config = described_class.new
      reporter = RSpec::Rewind::FlakyReporter.jsonl('tmp/custom.jsonl')

      config.flaky_reporter = reporter
      expect(config.flaky_report_path).to eq('tmp/custom.jsonl')

      config.flaky_reporter = Class.new do
        def record(_event); end
      end.new
      expect(config.flaky_report_path).to be_nil
    end

    it 'rejects reporters without record' do
      config = described_class.new

      expect do
        config.flaky_reporter = Object.new
      end.to raise_error(ArgumentError, /flaky_reporter must respond to #record/)
    end
  end

  describe '#freeze' do
    it 'freezes mutable policy arrays' do
      config = described_class.new
      config.retry_on = [RuntimeError]
      config.skip_retry_on = [IOError]
      config.metadata_report_keys = %i[file_path type]

      config.freeze

      expect { config.retry_on << StandardError }.to raise_error(FrozenError)
      expect { config.skip_retry_on << NoMethodError }.to raise_error(FrozenError)
      expect { config.metadata_report_keys << :js }.to raise_error(FrozenError)
    end
  end

  describe '#snapshot' do
    it 'returns a frozen copy without freezing the original policy arrays' do
      config = described_class.new
      config.retry_on = [RuntimeError]

      snapshot = config.snapshot

      expect(snapshot).to be_frozen
      expect { snapshot.retry_on << StandardError }.to raise_error(FrozenError)
      expect { config.retry_on << IOError }.not_to raise_error
    end
  end
end
