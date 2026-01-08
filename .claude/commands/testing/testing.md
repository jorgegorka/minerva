# Testing Practices Guide

Audience: developers writing tests. Goal: understand how tests are organized, how to write efficient coverage, and how to avoid common pitfalls in our multi-tenant Rails 8.1 app.

## Quick start (local)

- Run all tests: `bundle exec rake test`
- Faster: `bundle exec rake parallel:test`
- Single file: `bundle exec ruby -I test test/models/employee_test.rb`
- Single test: append `--name test_name`

## Layout and naming

- Tests live in `test/` mirroring app structure: `models/`, `fixtures/`, `test_helper.rb`, `account_info.rb`.
- File names end with `_test.rb` and follow the source path (`app/middleware/foo/bar.rb` ➝ `test/middleware/foo/bar_test.rb`).

## Global test configuration (see `test/test_helper.rb`)

- Parallel by default: `parallelize(workers: :number_of_processors)`.
- Fixtures: `fixtures :all` preloads everything under `test/fixtures/*.yml`.
- Locale: `I18n.locale = :es` (set explicitly in `ActiveSupport::TestCase`).
- Helpers mixed in everywhere:
  - `AccountInfo` for common fixtures (`employee`, `manager`, `admin`, `calahorra`, `athens`, `developers`, `sales`, `athens_team`, `account`).
  - Sorcery helpers (`login_user`, `login_user_post`) for auth flows.
  - `GeocoderTest` stubs geocoding (`Geocoder.configure(lookup: :test)` with a default stub).
- Stubbing:
  - DO NOT stub things unless is a third party library. 
  - Do not test private methods. We test private methods indirectly by testing the public methods that use them.

## Fixtures and test data

- Prefer existing fixtures for core entities; keep additions minimal and descriptive.
- Avoid deeply linked fixtures; add only what the test needs.
- For custom setup, build records in `setup` with clear intent; keep account scoping explicit.

## Writing tests by type

### Middleware / service objects

- Follow the callable pattern; test success and failure paths.
- Assert side effects (created/updated records, enqueued jobs) and return values.
- Stub external collaborators; avoid network calls.

### Finders / query objects

- Start from a clean, minimal dataset; create records that exercise each filter.
- Assert scoping to the current account and permission constraints.

### Controllers & integration

- Prefer integration tests (`ActionDispatch::IntegrationTest`) to cover routing, auth, and responses.
- Exercise both happy-path and error cases (missing params, unauthorized users).
- We put controller tests in the `integration` directory.
- **important** Never test instance variables or implementation details; assert response status, body content, and side effects only.

### Background jobs

- Use `assert_enqueued_jobs` to verify enqueueing; `perform_enqueued_jobs` to assert effects.
- Keep jobs idempotent; assert they scope to the correct account/user data.

### MCP tools/resources

- Validate parameters, authentication/authorization, scoping, response shape, and that sensitive data is not leaked.
- Stub downstream selectors/utilities where appropriate.

## Time-dependent code

- Use `travel_to`/`travel_back` (or `freeze_time`) for deterministic time assertions.
- Prefer `Time.zone`/`Date.current` helpers; avoid `sleep` or arbitrary delays.

## External services and stubbing

- Stub any HTTP or third-party calls; tests must be offline-safe.

## Efficient, reliable tests

- Keep each test focused on one behavior.
- Minimize data created; prefer fixtures/helpers over factories or broad setup.
- Avoid testing implementation details; test observable behavior and side effects.
- Ensure repeatability: no reliance on order, randomness, or global state leakage.
- Do not test private methods.  We test private methods indirectly by testing the public methods that use them.

## Debugging tips

- Verbose output: `bundle exec rake test TESTOPTS="-v"`.
- Run by name: `bundle exec ruby -I test path/to/file_test.rb --name test_case`.
- Use `binding.pry` in tests when needed; remove before committing.

## Author checklist for new tests

- Uses fixtures/helpers appropriately; minimal additional data.
- **important** Deterministic time handling (`travel_to`/`travel_back` as needed).
- External calls stubbed; no sleeps/timeouts.
- Covers both success and failure/edge paths.
