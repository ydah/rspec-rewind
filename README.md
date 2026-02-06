# rspec-rewind

[![CI](https://github.com/ydah/rspec-rewind/actions/workflows/ci.yml/badge.svg)](https://github.com/ydah/rspec-rewind/actions/workflows/ci.yml)

`rspec-rewind` is a modern retry orchestration gem for RSpec.
It was inspired by [`rspec-retry`](https://github.com/NoRedInk/rspec-retry), but focuses on deterministic control and flaky-test observability.

## Why another retry gem?

`rspec-rewind` is opinionated for current CI workflows:

- Clear semantics: `retries` means "extra attempts" (not total attempts).
- Retry policy controls: `retry_on`, `skip_retry_on`, and `retry_if` predicate.
- Built-in backoff strategies with optional jitter.
- Suite-level retry budget to avoid hidden CI slowdowns.
- Flaky detection events and optional JSONL report output.

## Installation

Add this line to your application's Gemfile:

```ruby
gem "rspec-rewind"
```

And then execute:

```bash
bundle install
```

## Quick start

```ruby
# spec/spec_helper.rb
require "rspec/rewind"

RSpec::Rewind.configure do |config|
  config.default_retries = 1
  config.backoff = RSpec::Rewind::Backoff.exponential(base: 0.1, factor: 2, max: 1.0)
  config.retry_on = [Net::ReadTimeout, Errno::ECONNRESET]
  config.skip_retry_on = [NoMethodError]
  config.retry_budget = 20
  config.flaky_report_path = "tmp/rspec-rewind/flaky.jsonl"
end
```

### Per-example override

```ruby
it "is eventually consistent", rewind: 3, rewind_wait: 0.2 do
  expect(fetch_remote_state).to eq("ready")
end

it "retries only transient HTTP failures",
   rewind: 2,
   rewind_retry_on: [Net::ReadTimeout, /502/],
   rewind_skip_retry_on: [NoMethodError],
   rewind_if: ->(exception, _example) { exception.message.include?("gateway") } do
  expect(call_api).to eq(:ok)
end
```

`rewind_skip_retry_on` is the preferred key. `rewind_skip_on` is still accepted as a legacy alias.
Callable filters can accept either `(exception)` or `(exception, example)`.

## Configuration reference

```ruby
RSpec::Rewind.configure do |config|
  config.default_retries = 0
  config.backoff = RSpec::Rewind::Backoff.fixed(0)
  config.retry_on = []
  config.skip_retry_on = []
  config.retry_if = nil
  config.retry_callback = ->(event) { puts "retry ##{event.attempt} for #{event.example_id}" }
  config.flaky_callback = ->(event) { puts "flaky: #{event.description}" }
  config.retry_budget = nil
  config.flaky_report_path = nil
  config.verbose = false
  config.display_retry_failure_messages = false
  config.clear_lets_on_failure = true
end
```

### Backoff helpers

```ruby
RSpec::Rewind::Backoff.fixed(0.2)
RSpec::Rewind::Backoff.linear(step: 0.1, max: 1.0)
RSpec::Rewind::Backoff.exponential(base: 0.1, factor: 2.0, max: 2.0, jitter: 0.2)
```

## JSONL flaky report format

Each entry contains:

- `schema_version`
- `status`
- `retry_reason`
- `example_id`
- `description`
- `location`
- `attempt`
- `retries`
- `exception_class`
- `exception_message`
- `duration`
- `sleep_seconds`
- `timestamp`

## Compatibility notes

- Ruby `>= 3.0`
- RSpec Core `>= 3.12`, `< 4.0`

## Development

```bash
bundle exec rspec
```

CI runs on every push and pull request, and validates:

- Specs across Ruby 3.0-3.4
- Gem packaging (`rake build`)
