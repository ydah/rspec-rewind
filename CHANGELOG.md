# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

### Added

- Added `rspec/rewind/core` for loading the API without auto-installing the RSpec hook.
- Added `RSPEC_REWIND_AUTO_INSTALL` and `RSPEC_REWIND_DISABLE` controls.
- Added retry lifecycle hooks: `before_retry`, `after_retry`, and `not_retried_callback`.
- Added retry summary and flaky-threshold controls: `display_retry_summary`, `fail_on_flaky`, and `max_flaky_examples`.
- Added retry limits and dry-run controls: `max_retries`, `max_elapsed_time`, `max_total_sleep`, and `dry_run`.
- Added process-aware retry budgets with `RSpec::Rewind::FileRetryBudget`.
- Added richer retry events with decision reasons, matcher details, failure fingerprints, timing, sleep, budget, and selected metadata fields.
- Added `not_retried` and `reset_failed` event reporting, plus `reset_failure_policy`.
- Added advanced policy controls for `retry_if_mode`, `retry_on_default`, and metadata append/override modes.
- Added injectable jitter RNG support for exponential backoff.

### Changed

- Retry event payloads are immutable.
- Runner configuration is snapshotted per example so later configuration changes do not affect in-flight retries.
- Flaky reporter path and reporter objects stay synchronized, and reporters are flushed and closed at suite end.

### Fixed

- Clamp retry sleep before sleeping when `max_total_sleep` is configured.
- Prevent `not_retried_callback` errors from masking the original suite result.
- Keep reporter lifecycle failures from interrupting suite shutdown unless strict callbacks are enabled.
- Revalidate existing retry matchers when strict matcher validation is enabled.
- Validate exponential backoff jitter RNG output and keep jittered delays within the configured maximum.

## 0.1.0 (2026-02-07)

- Initial release.
