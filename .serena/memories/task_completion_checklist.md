# Task Completion Checklist

When code changes are complete, run these checks locally:

1. `bundle exec rspec`
2. `bundle exec rake rubocop`
3. `bundle exec rake rbs`

Recommended additional checks when relevant:

- Coverage-sensitive changes: `COVERAGE=1 bundle exec rspec`
- Packaging/release-sensitive changes: `bundle exec rake build`
- Compatibility-sensitive changes: `BUNDLE_GEMFILE=gemfiles/rspec_3_12.gemfile bundle exec rspec`

Final hygiene before handing off:

- Review diff: `git diff --stat` and `git diff`
- Ensure docs/signatures updated if APIs/config changed (`README.md`, `sig/rspec/rewind.rbs`)
- Confirm no unintended files are staged (note: `Gemfile.lock` is gitignored in this repo).