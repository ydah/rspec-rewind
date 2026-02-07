# rspec-rewind: Project Overview

- Purpose: `rspec-rewind` is a Ruby gem that provides deterministic retry orchestration for RSpec examples, including retry policies, backoff strategies, retry budgets, and flaky-test observability.
- Type: Library gem (no standalone app server/CLI runtime).
- Main runtime entrypoint: `require "rspec/rewind"`.

## Tech Stack

- Language: Ruby (target Ruby `>= 3.1` per gemspec).
- Core dependency: `rspec-core >= 3.12, < 4.0`.
- Development/testing: `rspec`, `rake`, `simplecov`.
- Linting: `rubocop` + `rubocop-rspec`.
- Type signatures: `rbs` with signatures in `sig/`.
- CI: GitHub Actions (`.github/workflows/main.yml`).

## Rough Codebase Structure

- `lib/rspec/rewind.rb`: main loader/installation hook (`install!` around hook integration into RSpec).
- `lib/rspec/rewind/*.rb`: retry orchestration components (`Runner`, `RetryLoop`, `RetryGate`, `RetryTransition`, `FlakyTransition`, resolvers, policy/decision, notifier, context, etc.).
- `lib/rspec-rewind.rb`: top-level require shim.
- `sig/rspec/rewind.rbs`: RBS signatures for public/internal classes.
- `spec/`: unit/integration specs, mostly organized by component under `spec/rspec/rewind/`.
- `gemfiles/rspec_3_12.gemfile`: compatibility matrix Gemfile.
- `bin/setup`, `bin/console`: local development helpers.

## Repository Notes

- `Gemfile.lock` and `gemfiles/*.lock` are gitignored in this repository.
- CI quality checks include lint, type signature validation, coverage run, and gem build.