# Style and Conventions

## Ruby / General

- Most Ruby files begin with `# frozen_string_literal: true`.
- Prefer small, composable classes with clear single responsibilities (project has been refactored toward componentized orchestration).
- Error handling for callbacks/reporting is intentionally defensive (swallow callback/report errors, continue runner flow).

## RSpec Usage

- `spec/spec_helper.rb` disables monkey patching (`config.disable_monkey_patching!`).
- Derived metadata sets `rewind: false` unless explicitly specified.
- Expectation syntax is `expect` style.

## RuboCop Configuration Highlights (`.rubocop.yml`)

- Target Ruby: `3.1`
- `NewCops: enable`
- `Layout/LineLength: Max 120`
- `Style/Documentation: Enabled false`
- `Metrics/AbcSize: Max 30`
- `Metrics/ClassLength: Max 400`
- `Metrics/MethodLength: Max 60`
- `Metrics/CyclomaticComplexity: Max 15`
- `Metrics/PerceivedComplexity: Max 15`
- `Metrics/ParameterLists: Max 8`
- `Metrics/BlockLength` excludes `spec/**/*.rb`
- RSpec-specific:
  - `RSpec/ExampleLength: Max 20`
  - `RSpec/MultipleExpectations: Max 6`
  - `RSpec/InstanceVariable: Enabled false`
  - `RSpec/LeakyConstantDeclaration: Enabled false`

## Typing / Signatures

- RBS signatures live in `sig/` and are validated via `bundle exec rbs validate` (exposed as `rake rbs`).
- `sig/**/*` is excluded from RuboCop.