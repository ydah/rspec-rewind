# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RSpec::Rewind::FailureFingerprint do
  it 'builds a stable fingerprint from exception class, message, and top backtrace' do
    exception = RuntimeError.new('boom')
    exception.set_backtrace(['spec/example_spec.rb:3'])

    fingerprint = described_class.build(exception)

    expect(fingerprint).to eq('RuntimeError:boom:spec/example_spec.rb:3')
  end

  it 'returns nil without an exception' do
    expect(described_class.build(nil)).to be_nil
  end
end
