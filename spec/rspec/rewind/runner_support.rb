# frozen_string_literal: true

module RunnerSpecSupport
  class FakeExecutionResult
    attr_accessor :status, :exception, :pending_message, :run_time
  end

  class FakeExampleGroupInstance
    attr_reader :clear_lets_calls

    def initialize
      @clear_lets_calls = 0
    end

    def clear_lets
      @clear_lets_calls += 1
    end
  end

  class FakeExample
    attr_reader :metadata,
                :run_calls,
                :id,
                :full_description,
                :location,
                :execution_result,
                :example_group_instance

    attr_accessor :exception

    def initialize(outcomes:, metadata: {})
      @outcomes = outcomes.dup
      @metadata = metadata
      @run_calls = 0
      @id = 'spec/fake_spec.rb[1:1]'
      @full_description = 'fake example'
      @location = 'spec/fake_spec.rb:1'
      @execution_result = FakeExecutionResult.new
      @example_group_instance = FakeExampleGroupInstance.new
      @exception = nil
    end

    def run
      @run_calls += 1
      @exception = @outcomes.shift
    end

    def clear_exception
      @exception = nil
    end
  end

  class FakeRaisingExample < FakeExample
    def run
      @run_calls += 1
      outcome = @outcomes.shift

      if outcome.is_a?(Exception)
        @exception = nil
        raise outcome
      end

      @exception = outcome
    end
  end

  class CollectingReporter
    attr_reader :events

    def initialize
      @events = []
    end

    def record(event)
      @events << event
    end
  end

  def build_runner(outcomes:, metadata: {}, configure: nil, example_class: FakeExample)
    config = RSpec::Rewind::Configuration.new
    configure&.call(config)

    example = example_class.new(outcomes: outcomes, metadata: metadata)
    runner = RSpec::Rewind::Runner.new(example: example, configuration: config)
    [runner, example, config]
  end
end
