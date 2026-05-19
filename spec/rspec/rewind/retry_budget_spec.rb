# frozen_string_literal: true

require 'spec_helper'
require 'fileutils'
require 'tmpdir'

RSpec.describe RSpec::Rewind::RetryBudget do
  it 'allows unlimited retries when limit is nil' do
    budget = described_class.new(nil)

    3.times { expect(budget.consume!).to be(true) }
    expect(budget.unlimited?).to be(true)
    expect(budget.remaining).to eq(Float::INFINITY)
  end

  it 'stops consuming retries once the budget is exhausted' do
    budget = described_class.new(2)

    expect(budget.consume!).to be(true)
    expect(budget.consume!).to be(true)
    expect(budget.consume!).to be(false)
    expect(budget.used).to eq(2)
    expect(budget.remaining).to eq(0)
  end

  it 'returns budget decisions and can reset usage' do
    budget = described_class.new(1)

    decision = budget.consume

    expect(decision).to have_attributes(
      allowed?: true,
      limit: 1,
      used: 1,
      remaining: 0
    )

    budget.reset!
    expect(budget.used).to eq(0)
    expect(budget.remaining).to eq(1)
  end

  it 'raises on invalid limit' do
    expect do
      described_class.new('many')
    end.to raise_error(ArgumentError, /retry budget must be nil or a non-negative integer/)
    expect { described_class.new(-1) }.to raise_error(ArgumentError, /retry budget must be >= 0/)
  end
end

RSpec.describe RSpec::Rewind::FileRetryBudget do
  it 'shares retry budget through a locked file' do
    Dir.mktmpdir do |dir|
      budget = described_class.new(limit: 2, path: File.join(dir, 'budget'))

      expect(budget.consume!).to be(true)
      expect(budget.consume!).to be(true)
      expect(budget.consume!).to be(false)
      expect(budget.used).to eq(2)
      expect(budget.remaining).to eq(0)

      budget.reset!
      expect(budget.used).to eq(0)
    end
  end

  it 'coordinates budget consumption across processes' do
    skip 'fork is not available on this platform' unless Process.respond_to?(:fork)

    Dir.mktmpdir do |dir|
      path = File.join(dir, 'budget')
      result_dir = File.join(dir, 'results')
      FileUtils.mkdir_p(result_dir)

      pids = 4.times.map do |index|
        fork do
          budget = described_class.new(limit: 2, path: path)
          result = budget.consume.allowed? ? '1' : '0'
          File.write(File.join(result_dir, index.to_s), result)
        end
      end
      pids.each { |pid| Process.wait(pid) }

      successes = Dir.children(result_dir).sum do |file|
        Integer(File.read(File.join(result_dir, file)))
      end

      expect(successes).to eq(2)
      expect(described_class.new(limit: 2, path: path).used).to eq(2)
    end
  end

  it 'raises on invalid limit' do
    Dir.mktmpdir do |dir|
      expect do
        described_class.new(limit: -1, path: File.join(dir, 'budget'))
      end.to raise_error(ArgumentError, /file retry budget must be >= 0/)
    end
  end
end
