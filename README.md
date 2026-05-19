# rspec-rewind

Deterministic retry orchestration for flaky RSpec examples.

[![Gem Version](https://badge.fury.io/rb/rspec-rewind.svg)](https://badge.fury.io/rb/rspec-rewind)
[![CI](https://github.com/ydah/rspec-rewind/actions/workflows/main.yml/badge.svg)](https://github.com/ydah/rspec-rewind/actions/workflows/main.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE.txt)

`rspec-rewind` retries RSpec examples with explicit retry counts, exception filters,
backoff strategies, retry budgets, and flaky-test reporting.

## Installation

```ruby
gem "rspec-rewind"
```

Then run:

```bash
bundle install
```

## Usage

Require `rspec/rewind` from your RSpec setup file. This installs the around hook
automatically.

```ruby
# spec/spec_helper.rb
require "rspec/rewind"

RSpec::Rewind.configure do |config|
  config.default_retries = 1
  config.retry_on = [Net::ReadTimeout, Errno::ECONNRESET]
  config.skip_retry_on = [NoMethodError]
  config.backoff = RSpec::Rewind::Backoff.exponential(base: 0.1, factor: 2.0, max: 1.0)
  config.retry_budget = 20
  config.flaky_report_path = "tmp/rspec-rewind/flaky.jsonl"
end
```

Retry counts are extra attempts. `rewind: 2` can run the example up to three
times total.

```ruby
it "eventually becomes consistent", rewind: 2 do
  expect(fetch_remote_state).to eq("ready")
end
```

## Per-Example Controls

```ruby
it "retries transient API failures",
   rewind: 3,
   rewind_wait: 0.2,
   rewind_retry_on: [Net::ReadTimeout, /502/],
   rewind_skip_retry_on: [NoMethodError],
   rewind_if: ->(exception, _example) { exception.message.include?("gateway") } do
  expect(call_api).to eq(:ok)
end
```

| Key | Meaning |
| --- | --- |
| `rewind` | Extra retry count. `true` uses the configured default; `false` disables retries. |
| `rewind_wait` | Fixed delay before the next attempt. |
| `rewind_backoff` | Numeric or callable backoff strategy. |
| `rewind_retry_on` | Additional retry allow-list matchers. |
| `rewind_skip_retry_on` | Additional retry deny-list matchers. Checked before allow-list matchers. |
| `rewind_if` | Predicate that decides whether the failure should retry. |

`retry_on` and `skip_retry_on` matchers can be exception classes, regexps, or
callables.

## Backoff

```ruby
RSpec::Rewind::Backoff.fixed(0.2)
RSpec::Rewind::Backoff.linear(step: 0.1, max: 1.0)
RSpec::Rewind::Backoff.exponential(base: 0.1, factor: 2.0, max: 2.0, jitter: 0.2)
```

## Observability

Use callbacks when you want to send retry events to logs or metrics.

```ruby
RSpec::Rewind.configure do |config|
  config.retry_callback = ->(event) { warn "[retry] #{event.example_id} attempt=#{event.attempt}" }
  config.flaky_callback = ->(event) { warn "[flaky] #{event.example_id}" }
end
```

Set `flaky_report_path` to write flaky examples as JSONL:

```ruby
RSpec::Rewind.configure do |config|
  config.flaky_report_path = "tmp/rspec-rewind/flaky.jsonl"
end
```

## Environment

```bash
RSPEC_REWIND_RETRIES=2 bundle exec rspec
RSPEC_REWIND_DISABLE=1 bundle exec rspec
```

`RSPEC_REWIND_RETRIES` takes priority over configured defaults and metadata.

## Compatibility

- Ruby `>= 3.1`
- RSpec Core `>= 3.12`, `< 4.0`

## Development

```bash
bundle install
bundle exec rake spec
bundle exec rake rubocop
bundle exec rake rbs
```

## License

Released under the [MIT License](LICENSE.txt).
