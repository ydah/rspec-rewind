# frozen_string_literal: true

require 'spec_helper'
require 'open3'
require 'tmpdir'
require 'rbconfig'

RSpec.describe RSpec::Rewind do
  let(:lib_path) { File.expand_path('../../../lib', __dir__) }

  def run_temp_rspec(example_source, env: {})
    Dir.mktmpdir('rspec-rewind-integration') do |dir|
      spec_path = File.join(dir, 'integration_spec.rb')
      File.write(spec_path, example_source)

      Open3.capture3(
        env,
        RbConfig.ruby,
        '-S',
        'rspec',
        '--options',
        File::NULL,
        spec_path,
        '--format',
        'progress'
      )
    end
  end

  it 'retries failing examples through the installed around hook' do
    source = <<~RUBY
      # frozen_string_literal: true

      $LOAD_PATH.unshift(#{lib_path.inspect})
      require "rspec/rewind"

      RSpec::Rewind.reset_configuration!
      RSpec::Rewind.configure { |config| config.default_retries = 1 }

      attempts = 0

      RSpec.describe "rewind integration" do
        it "passes on second attempt" do
          attempts += 1
          raise "first attempt fails" if attempts == 1
        end
      end
    RUBY

    stdout, stderr, status = run_temp_rspec(source)

    aggregate_failures do
      expect(status.success?).to be(true), "stdout:\n#{stdout}\nstderr:\n#{stderr}"
      expect(stdout).to include('1 example, 0 failures')
    end
  end

  it 'does not retry when rewind: false disables the hook' do
    source = <<~RUBY
      # frozen_string_literal: true

      $LOAD_PATH.unshift(#{lib_path.inspect})
      require "rspec/rewind"

      RSpec::Rewind.reset_configuration!
      RSpec::Rewind.configure { |config| config.default_retries = 1 }

      attempts = 0

      RSpec.describe "rewind disabled", rewind: false do
        it "fails without retry" do
          attempts += 1
          raise "no retry expected" if attempts == 1
        end
      end
    RUBY

    stdout, stderr, status = run_temp_rspec(source)

    aggregate_failures do
      expect(status.success?).to be(false), "stdout:\n#{stdout}\nstderr:\n#{stderr}"
      expect(stdout).to include('1 example, 1 failure')
    end
  end

  it 'ignores retry: false metadata and still retries by default policy' do
    source = <<~RUBY
      # frozen_string_literal: true

      $LOAD_PATH.unshift(#{lib_path.inspect})
      require "rspec/rewind"

      RSpec::Rewind.reset_configuration!
      RSpec::Rewind.configure { |config| config.default_retries = 1 }

      attempts = 0

      RSpec.describe "retry metadata ignored", retry: false do
        it "passes after retry" do
          attempts += 1
          raise "first attempt fails" if attempts == 1
        end
      end
    RUBY

    stdout, stderr, status = run_temp_rspec(source)

    aggregate_failures do
      expect(status.success?).to be(true), "stdout:\n#{stdout}\nstderr:\n#{stderr}"
      expect(stdout).to include('1 example, 0 failures')
    end
  end

  it 'does not auto-install when requiring core entrypoint' do
    source = <<~RUBY
      # frozen_string_literal: true

      $LOAD_PATH.unshift(#{lib_path.inspect})
      require "rspec/rewind/core"

      RSpec::Rewind.reset_configuration!
      RSpec::Rewind.configure { |config| config.default_retries = 1 }

      attempts = 0

      RSpec.describe "manual install" do
        it "fails without installed hook" do
          attempts += 1
          raise "first attempt fails" if attempts == 1
        end
      end
    RUBY

    stdout, stderr, status = run_temp_rspec(source)

    aggregate_failures do
      expect(status.success?).to be(false), "stdout:\n#{stdout}\nstderr:\n#{stderr}"
      expect(stdout).to include('1 example, 1 failure')
    end
  end

  it 'supports manual install from core entrypoint' do
    source = <<~RUBY
      # frozen_string_literal: true

      $LOAD_PATH.unshift(#{lib_path.inspect})
      require "rspec/rewind/core"

      RSpec::Rewind.reset_configuration!
      RSpec::Rewind.configure { |config| config.default_retries = 1 }
      RSpec::Rewind.install!

      attempts = 0

      RSpec.describe "manual install" do
        it "passes after manual install" do
          attempts += 1
          raise "first attempt fails" if attempts == 1
        end
      end
    RUBY

    stdout, stderr, status = run_temp_rspec(source)

    aggregate_failures do
      expect(status.success?).to be(true), "stdout:\n#{stdout}\nstderr:\n#{stderr}"
      expect(stdout).to include('1 example, 0 failures')
    end
  end

  it 'retries inherited metadata in shared examples' do
    source = <<~RUBY
      # frozen_string_literal: true

      $LOAD_PATH.unshift(#{lib_path.inspect})
      require "rspec/rewind"

      RSpec::Rewind.reset_configuration!

      attempts = 0

      RSpec.shared_examples "eventually stable" do
        it "passes on retry" do
          attempts += 1
          raise "first attempt fails" if attempts == 1
        end
      end

      RSpec.describe "nested metadata", rewind: 1 do
        context "shared" do
          include_examples "eventually stable"
        end
      end
    RUBY

    stdout, stderr, status = run_temp_rspec(source)

    aggregate_failures do
      expect(status.success?).to be(true), "stdout:\n#{stdout}\nstderr:\n#{stderr}"
      expect(stdout).to include('1 example, 0 failures')
    end
  end

  it 'does not retry skipped examples' do
    source = <<~RUBY
      # frozen_string_literal: true

      $LOAD_PATH.unshift(#{lib_path.inspect})
      require "rspec/rewind"

      RSpec::Rewind.reset_configuration!
      RSpec::Rewind.configure { |config| config.default_retries = 2 }

      attempts = 0

      RSpec.configure do |config|
        config.after(:suite) { raise "retried skip" unless attempts == 1 }
      end

      RSpec.describe "skip integration" do
        it "skips once" do
          attempts += 1
          skip "not relevant"
        end
      end
    RUBY

    stdout, stderr, status = run_temp_rspec(source)

    aggregate_failures do
      expect(status.success?).to be(true), "stdout:\n#{stdout}\nstderr:\n#{stderr}"
      expect(stdout).to include('1 example, 0 failures, 1 pending')
    end
  end

  it 'keeps pending examples pending without retry inflation' do
    source = <<~RUBY
      # frozen_string_literal: true

      $LOAD_PATH.unshift(#{lib_path.inspect})
      require "rspec/rewind"

      RSpec::Rewind.reset_configuration!
      RSpec::Rewind.configure { |config| config.default_retries = 2 }

      attempts = 0

      RSpec.configure do |config|
        config.after(:suite) { raise "retried pending" unless attempts == 1 }
      end

      RSpec.describe "pending integration" do
        it "is pending" do
          pending "not implemented"
          attempts += 1
          raise "expected pending failure"
        end
      end
    RUBY

    stdout, stderr, status = run_temp_rspec(source)

    aggregate_failures do
      expect(status.success?).to be(true), "stdout:\n#{stdout}\nstderr:\n#{stderr}"
      expect(stdout).to include('1 example, 0 failures, 1 pending')
    end
  end

  it 'retries aggregate failures through the installed hook' do
    source = <<~RUBY
      # frozen_string_literal: true

      $LOAD_PATH.unshift(#{lib_path.inspect})
      require "rspec/rewind"

      RSpec::Rewind.reset_configuration!

      attempts = 0

      RSpec.describe "aggregate failures", rewind: 1 do
        it "passes on retry" do
          attempts += 1

          aggregate_failures do
            expect(attempts).to eq(2)
            expect(attempts).to be_even
          end
        end
      end
    RUBY

    stdout, stderr, status = run_temp_rspec(source)

    aggregate_failures do
      expect(status.success?).to be(true), "stdout:\n#{stdout}\nstderr:\n#{stderr}"
      expect(stdout).to include('1 example, 0 failures')
    end
  end

  it 'retries after hook failures' do
    source = <<~RUBY
      # frozen_string_literal: true

      $LOAD_PATH.unshift(#{lib_path.inspect})
      require "rspec/rewind"

      RSpec::Rewind.reset_configuration!

      attempts = 0

      RSpec.describe "after hook failure", rewind: 1 do
        after do
          raise "after failed" if attempts == 1
        end

        it "passes on retry after hook" do
          attempts += 1
        end
      end
    RUBY

    stdout, stderr, status = run_temp_rspec(source)

    aggregate_failures do
      expect(status.success?).to be(true), "stdout:\n#{stdout}\nstderr:\n#{stderr}"
      expect(stdout).to include('1 example, 0 failures')
    end
  end

  it 'preserves surrounding around hook order across retries' do
    source = <<~RUBY
      # frozen_string_literal: true

      $LOAD_PATH.unshift(#{lib_path.inspect})
      require "rspec/rewind"

      RSpec::Rewind.reset_configuration!

      events = []
      attempts = 0

      RSpec.configure do |config|
        config.around(:each) do |example|
          events << "outer-before"
          example.run
          events << "outer-after"
        end

        config.after(:suite) do
          expected = ["outer-before", "outer-after", "outer-before", "outer-after"]
          raise "unexpected around order: \#{events.inspect}" unless events == expected
        end
      end

      RSpec.describe "around order", rewind: 1 do
        it "passes after retry" do
          attempts += 1
          raise "first attempt fails" if attempts == 1
        end
      end
    RUBY

    stdout, stderr, status = run_temp_rspec(source)

    aggregate_failures do
      expect(status.success?).to be(true), "stdout:\n#{stdout}\nstderr:\n#{stderr}"
      expect(stdout).to include('1 example, 0 failures')
    end
  end

  it 'prints a retry summary when enabled' do
    source = <<~RUBY
      # frozen_string_literal: true

      $LOAD_PATH.unshift(#{lib_path.inspect})
      require "rspec/rewind"

      RSpec::Rewind.reset_configuration!
      RSpec::Rewind.configure { |config| config.display_retry_summary = true }

      attempts = 0

      RSpec.describe "summary", rewind: 1 do
        it "passes after retry" do
          attempts += 1
          raise "first attempt fails" if attempts == 1
        end
      end
    RUBY

    stdout, stderr, status = run_temp_rspec(source)

    aggregate_failures do
      expect(status.success?).to be(true), "stdout:\n#{stdout}\nstderr:\n#{stderr}"
      expect(stdout).to include('[rspec-rewind] 1 flaky examples, 1 retry attempts')
    end
  end

  it 'fails the suite when fail_on_flaky is enabled' do
    source = <<~RUBY
      # frozen_string_literal: true

      $LOAD_PATH.unshift(#{lib_path.inspect})
      require "rspec/rewind"

      RSpec::Rewind.reset_configuration!
      RSpec::Rewind.configure { |config| config.fail_on_flaky = true }

      attempts = 0

      RSpec.describe "flaky threshold", rewind: 1 do
        it "passes after retry" do
          attempts += 1
          raise "first attempt fails" if attempts == 1
        end
      end
    RUBY

    stdout, stderr, status = run_temp_rspec(source)

    aggregate_failures do
      expect(status.success?).to be(false), "stdout:\n#{stdout}\nstderr:\n#{stderr}"
      expect("#{stdout}\n#{stderr}").to include('rspec-rewind observed 1 flaky example')
    end
  end
end
