---
name: rails-tdd
description: Test-driven development loop for Ruby on Rails (Minitest or RSpec). Use when implementing a feature, fixing a bug, or changing behaviour in a Rails/Ruby project.
---

# Rails TDD

## 0. Detect the test setup
- `test/` + `test_helper.rb` → Minitest: `bin/rails test <file>:<line>`
- `spec/` + `spec_helper.rb`/`rails_helper.rb` → RSpec: `bundle exec rspec <file>:<line>`
- Look at fixtures vs factories (`test/fixtures`, `spec/factories`) and reuse the style already used.
- If the test DB is stale (`ActiveRecord::PendingMigrationError`), run `bin/rails db:test:prepare`.

## 1. Red
- Pick the **lowest layer** that proves the behaviour: model test > request/integration test > system test.
- Write ONE failing test that states the behaviour in its name (`test "rejects duplicate emails"`).
- Run only that test. Confirm it fails **for the expected reason** (assertion, not a typo or a load error).

## 2. Green
- Write the minimal code to pass. Don't add anything the test doesn't require.
- Run the single test again. Then run the file.

## 3. Refactor
- Remove duplication and improve names, keeping the test green.
- Run the related directory (`bin/rails test test/models`), then the **full suite** before handing off.

## Test layers cheat-sheet
| Behaviour | Minitest | RSpec |
|---|---|---|
| Validations, scopes, methods | `test/models` (`ActiveSupport::TestCase`) | `spec/models` |
| HTTP status, redirects, JSON | `test/controllers` or `test/integration` (`ActionDispatch::IntegrationTest`) | `spec/requests` |
| Full browser flow (JS) | `test/system` (`ApplicationSystemTestCase`) | `spec/system` |
| Jobs / mailers | `test/jobs`, `test/mailers` | `spec/jobs`, `spec/mailers` |

## Rules
- Never delete, skip (`skip`, `xit`) or weaken an existing test to get green. If a test looks wrong, say so and ask.
- Cover the edge cases too: nil or blank input, unauthorized access, invalid records and boundaries.
- Report the real command output (e.g. `12 runs, 30 assertions, 0 failures`).
