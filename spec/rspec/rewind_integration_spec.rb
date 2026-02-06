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

  it 'does not retry when retry: false disables compatibility path' do
    source = <<~RUBY
      # frozen_string_literal: true

      $LOAD_PATH.unshift(#{lib_path.inspect})
      require "rspec/rewind"

      RSpec::Rewind.reset_configuration!
      RSpec::Rewind.configure { |config| config.default_retries = 1 }

      attempts = 0

      RSpec.describe "retry disabled", retry: false do
        it "fails without retry" do
          attempts += 1
          raise "compat path disabled" if attempts == 1
        end
      end
    RUBY

    stdout, stderr, status = run_temp_rspec(source)

    aggregate_failures do
      expect(status.success?).to be(false), "stdout:\n#{stdout}\nstderr:\n#{stderr}"
      expect(stdout).to include('1 example, 1 failure')
    end
  end
end
