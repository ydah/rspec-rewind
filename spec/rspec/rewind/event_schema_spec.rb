# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'RSpec::Rewind event schema' do
  it 'keeps the schema version stable for retry, flaky, not_retried, and reset_failed events' do
    %i[retrying flaky not_retried reset_failed].each do |status|
      event = RSpec::Rewind::Event.new(
        schema_version: RSpec::Rewind::EVENT_SCHEMA_VERSION,
        status: status,
        example_id: 'spec/example_spec.rb[1:1]',
        description: 'example',
        location: 'spec/example_spec.rb:1',
        attempt: 1,
        retries: 2,
        duration: 0.1,
        sleep_seconds: 0.0,
        timestamp: '2026-05-19T00:00:00Z'
      )

      expect(event.to_h).to include(
        schema_version: 1,
        status: status,
        example_id: 'spec/example_spec.rb[1:1]',
        max_attempts: nil,
        budget_remaining: nil,
        metadata: nil
      )
    end
  end

  it 'exposes all fields through to_h' do
    event = RSpec::Rewind::Event.new

    expect(event.to_h.keys).to eq(RSpec::Rewind::Event::FIELDS)
  end
end
