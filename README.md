<h1 align="center">rspec-rewind</h1>

<p align="center">
  Deterministic retry orchestration for flaky RSpec examples.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/ruby-%3E%3D%203.1-ruby.svg" alt="Ruby Version">
  <img src="https://img.shields.io/badge/rspec--core-%3E%3D%203.12%2C%20%3C%204.0-brightgreen.svg" alt="RSpec Core Version">
  <img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="License">
  <a href="https://badge.fury.io/rb/rspec-rewind"><img src="https://badge.fury.io/rb/rspec-rewind.svg" alt="Gem Version" height="18"></a>
  <a href="https://github.com/ydah/rspec-rewind/actions/workflows/main.yml">
    <img src="https://github.com/ydah/rspec-rewind/actions/workflows/main.yml/badge.svg" alt="CI Status">
  </a>
</p>

<p align="center">
  <a href="#installation">Installation</a> •
  <a href="#quick-start">Quick Start</a> •
  <a href="#per-example-controls">Per-Example Controls</a> •
  <a href="#configuration">Configuration</a> •
  <a href="#observability">Observability</a> •
  <a href="#compatibility">Compatibility</a>
</p>

`rspec-rewind` is a modern retry gem for RSpec, inspired by [`rspec-retry`](https://github.com/NoRedInk/rspec-retry), with deterministic control and flaky-test observability for CI-heavy projects.

## Why rspec-rewind

- `retries` always means "extra attempts" (not total attempts).
- Retry filtering with `retry_on`, `skip_retry_on`, and `retry_if`.
- Configurable delay via fixed, linear, exponential, or custom backoff.
- Suite-level retry budget to prevent hidden retry inflation.
- Flaky detection hooks and optional JSONL reporting.

## Installation

Add to your Gemfile:

```ruby
gem "rspec-rewind"
```

Then run:

```bash
bundle install
```

## Quick Start

`require "rspec/rewind"` installs an around hook automatically.

```ruby
# spec/spec_helper.rb
require "rspec/rewind"

RSpec::Rewind.configure do |config|
  config.default_retries = 1
  config.backoff = RSpec::Rewind::Backoff.exponential(base: 0.1, factor: 2.0, max: 1.0, jitter: 0.2)
  config.retry_on = [Net::ReadTimeout, Errno::ECONNRESET]
  config.skip_retry_on = [NoMethodError]
  config.retry_budget = 20
  config.flaky_report_path = "tmp/rspec-rewind/flaky.jsonl"
end
```

Basic per-example retry:

```ruby
it "eventually becomes consistent", rewind: 2 do
  expect(fetch_remote_state).to eq("ready")
end
```

## Per-Example Controls

```ruby
it "uses metadata overrides",
   rewind: 3,
   rewind_wait: 0.2,
   rewind_retry_on: [Net::ReadTimeout, /502/],
   rewind_skip_retry_on: [NoMethodError],
   rewind_if: ->(exception, _example) { exception.message.include?("gateway") } do
  expect(call_api).to eq(:ok)
end
```

| Metadata key | Description |
| --- | --- |
| `rewind` | Retry count override. `true` = use default, `false` = disable retries for that example/group. |
| `rewind_wait` | Fixed sleep before next attempt. |
| `rewind_backoff` | Backoff strategy (numeric or callable). |
| `rewind_retry_on` | Extra allow-list matchers. |
| `rewind_skip_retry_on` | Extra deny-list matchers (checked first). |
| `rewind_if` | Predicate `(exception)` or `(exception, example)` returning truthy/falsey. |

Matcher types for `retry_on` and `skip_retry_on`: `Module`, `Regexp`, or callable.

## Configuration

```ruby
RSpec::Rewind.configure do |config|
  config.default_retries = 0
  config.backoff = RSpec::Rewind::Backoff.fixed(0)
  config.retry_on = []
  config.skip_retry_on = []
  config.retry_if = nil
  config.retry_callback = nil
  config.flaky_callback = nil
  config.retry_budget = nil
  config.flaky_report_path = nil
  config.verbose = false
  config.display_retry_failure_messages = false
  config.clear_lets_on_failure = true
end
```

Backoff helpers:

```ruby
RSpec::Rewind::Backoff.fixed(0.2)
RSpec::Rewind::Backoff.linear(step: 0.1, max: 1.0)
RSpec::Rewind::Backoff.exponential(base: 0.1, factor: 2.0, max: 2.0, jitter: 0.2)
```

Environment override:

```bash
RSPEC_REWIND_RETRIES=2 bundle exec rspec
```

`RSPEC_REWIND_RETRIES` has highest priority over defaults and metadata.

## Retry Decision Order

1. Stop if no exception happened.
2. Stop if exception matches any `skip_retry_on`.
3. If `retry_on` is set, stop unless exception matches at least one matcher.
4. If `retry_if` exists, retry only when predicate returns truthy.
5. Stop if retry budget is exhausted.

## Observability

### Retry and Flaky Callbacks

```ruby
RSpec::Rewind.configure do |config|
  config.retry_callback = ->(event) do
    puts "[retry] #{event.example_id} attempt=#{event.attempt}/#{event.retries}"
  end

  config.flaky_callback = ->(event) do
    puts "[flaky] #{event.description} (attempt #{event.attempt})"
  end
end
```

### JSONL Flaky Report

```ruby
RSpec::Rewind.configure do |config|
  config.flaky_report_path = "tmp/rspec-rewind/flaky.jsonl"
end
```

Each flaky JSONL row includes:

- `schema_version`
- `status` (`flaky`)
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

## Compatibility

- Ruby `>= 3.1`
- RSpec Core `>= 3.12`, `< 4.0`

## Development

```bash
bundle exec rspec
bundle exec rake rbs
```

CI validates:

- Specs across Ruby 3.1, 3.2, 3.3, 3.4, 4.0, and head
- Minimum compatibility with RSpec 3.12 (`BUNDLE_GEMFILE=gemfiles/rspec_3_12.gemfile`)
- Type signatures (`rake rbs`)
- Coverage threshold (`COVERAGE=1 rspec`)
- Gem packaging (`rake build`)
- Dependency security audit (`bundler-audit`)

## Contributing

Bug reports and pull requests are welcome on GitHub:
https://github.com/ydah/rspec-rewind

## License

Released under the [MIT License](LICENSE.txt).
