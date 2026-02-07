# Suggested Commands (Darwin/macOS)

## Basic Local Setup

- Install deps: `bundle install`
- Helper script: `bin/setup`

## Development/Test Commands

- Run all specs: `bundle exec rspec`
- Run RSpec rake task: `bundle exec rake spec`
- Run lint: `bundle exec rake rubocop`
- Run RBS validation: `bundle exec rake rbs`
- Run default rake task (spec + rubocop + rbs): `bundle exec rake`
- Run coverage mode: `COVERAGE=1 bundle exec rspec`
- Build gem: `bundle exec rake build`

## Compatibility / CI-Parity Commands

- RSpec 3.12 compatibility run:
  `BUNDLE_GEMFILE=gemfiles/rspec_3_12.gemfile bundle exec rspec`
- Dependency audit flow used in CI:
  1. `bundle lock`
  2. `gem install bundler-audit --no-document`
  3. `bundle-audit check --update`

## Entrypoint / Interactive

- IRB console with gem loaded: `bin/console`
- In Ruby code/specs: `require "rspec/rewind"`

## Useful System Commands (Darwin)

- Navigation/files: `pwd`, `ls`, `cd`, `find`
- Search text/files: `rg`, `grep`
- Git: `git status`, `git diff`, `git add`, `git commit`, `git log --oneline`
- Inspect files quickly: `sed -n 'start,endp' <file>`
- macOS-specific handy commands: `open <path>` (open in Finder/app), `pbcopy`, `pbpaste`