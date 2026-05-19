# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'RSpec::Rewind API boundaries' do
  it 'declares the public API surface' do
    expect(RSpec::Rewind::PUBLIC_API).to include(
      RSpec::Rewind::Backoff,
      RSpec::Rewind::Configuration,
      RSpec::Rewind::Event,
      RSpec::Rewind::Runner
    )
  end

  it 'declares internal orchestration classes separately' do
    expect(RSpec::Rewind::INTERNAL_API).to include(
      RSpec::Rewind::RetryLoop,
      RSpec::Rewind::RunnerComponents,
      RSpec::Rewind::RSpecAdapter
    )
  end
end
