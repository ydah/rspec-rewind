# frozen_string_literal: true

require_relative "lib/rspec/rewind/version"

Gem::Specification.new do |spec|
  spec.name = "rspec-rewind"
  spec.version = RSpec::Rewind::VERSION
  spec.authors = ["Yudai Takada"]
  spec.email = ["t.yudai92@gmail.com"]

  spec.summary = "Modern retry orchestration for flaky RSpec examples"
  spec.description = <<~DESC
    rspec-rewind provides deterministic retry policies, exception filters,
    configurable backoff strategies, and flaky test observability for RSpec.
  DESC
  spec.homepage = "https://github.com/ydah/rspec-rewind"
  spec.license = "MIT"
  spec.required_ruby_version = Gem::Requirement.new(">= 3.0")

  spec.metadata = {
    "homepage_uri" => spec.homepage,
    "source_code_uri" => spec.homepage,
    "changelog_uri" => "#{spec.homepage}/blob/main/CHANGELOG.md"
  }

  spec.files = Dir.chdir(__dir__) do
    Dir.glob("{lib,spec}/**/*", File::FNM_DOTMATCH).reject do |path|
      path.include?("/.") || File.directory?(path)
    end + %w[Gemfile Rakefile README.md rspec-rewind.gemspec]
  end

  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "rspec-core", ">= 3.12", "< 4.0"
end
