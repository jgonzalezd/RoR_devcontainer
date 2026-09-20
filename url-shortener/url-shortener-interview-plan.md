# Toptal Interview: URL Shortener API — Stage-by-Stage Development Plan

## Overview
Building a URL shortener in Sinatra (Ruby on Rails-like framework) with TDD, security-first mindset, and professional code quality. The goal is to demonstrate:
- Clear separation of concerns (models, services, controllers)
- Test-driven development at every layer
- Security awareness (injection, XSS, rate limiting)
- Professional code quality (no spaguetti, clear naming, DRY)
- Efficient AI utilization (prompt engineering, code generation, refinement)

---

## Stage 1: Requirements & Acceptance Criteria Definition

### Goal
Define the feature scope and measurable acceptance criteria before writing any code.

### Deliverables
- Feature specification doc
- Acceptance criteria matrix (functional + non-functional)
- AI prompt template for initial design

### Acceptance Criteria (Up-front)
| ID | Criterion | Success Metric |
|---|---|---|
| AC-1 | All short URLs must be globally unique | SHA-256 hash of original URL + random suffix, collision-free |
| AC-2 | Redirect must be 302 with proper Location header | HTTP 302 Found, Location points to expanded URL |
| AC-3 | Max redirect depth ≤ 3 (to prevent infinite loops) | Circuit-breaker or depth counter enforced |
| AC-4 | Click analytics tracked (count, timestamp, IP) | Database record created per click |
| AC-5 | Rate limiting: max 100 requests/minute per client IP | 429 Too Many Requests after threshold |
| AC-6 | Input validation: reject malformed URLs, SQL injection attempts | 400 Bad Request with descriptive error |
| AC-7 | No hardcoded secrets; credentials from environment variables | Config managed via ENV, not source code |
| AC-8 | Code passes linting (RuboCop) and static analysis | Zero critical violations |
| AC-9 | Documentation: README with API contract, usage examples | Markdown doc generated |

### AI Usage
- **Prompt**: "Design a URL shortener API in Sinatra. Define models, routes, and core logic. Focus on clean architecture, TDD, and security. Output a spec document and a test skeleton."
- **Iteration**: After receiving initial output, refine acceptance criteria based on feedback, then lock them.

### Convergence Mechanism
- Review AC-1 through AC-9 together
- Confirm no ambiguity
- Lock criteria and proceed to Stage 2

---

## Stage 2: Domain Model Design & TDD Tests

### Goal
Define the data model and write failing tests first (TDD).

### Layers
1. **Models** (`app/models/short_url.rb`, `app/models/user.rb`)
2. **Services** (`app/services/url_shortener.rb`) — business logic
3. **Controllers** (`app/controllers/short_url_controller.rb`)

### Acceptance Criteria for Stage 2
- ✅ Model defines primary key, validations, associations
- ✅ Service implements `create`, `expand`, `analytics` methods
- ✅ Controller maps HTTP verbs to service methods
- ✅ All public methods have unit tests (JUnit-style or Minitest)
- ✅ Tests fail initially (red phase)

### AI Workflow
- Generate model skeletons and test stubs
- Refine based on AC-1-7
- Ensure tests are isolated and deterministic

### Quality Checks
- No magic strings in code
- Constants defined as module constants
- Proper error handling (custom exceptions)

---

## Stage 3: Service Layer Implementation (TDD)

### Goal
Implement business logic with comprehensive unit tests.

### Acceptance Criteria
| ID | Criterion |
|---|---|
| SC-1 | Creating a short URL generates a unique identifier and stores mapping |
| SC-2 | Expanding a short URL returns the original URL |
| SC-3 | Analytics records are created for each expansion |
| SC-4 | Rate limiting prevents abuse (429 on excess requests) |
| SC-5 | Invalid input (malformed URL) returns 400 |
| SC-6 | Duplicate short URL detection (return existing or reject) |
| SC-7 | Service methods are pure (no side effects except DB writes) |

### AI Usage
- Prompt: "Implement the URLShortenerService class with create, expand, and track methods. Write failing tests first. Ensure each test verifies a single behavior."
- Run tests after each change (red-green cycle)

### Quality Gates
- RuboCop score ≥ 90
- No flaky tests (run 5x to confirm stability)
- Each test has a clear name describing the scenario

---

## Stage 4: API Controller Implementation (TDD)

### Goal
Wire the service layer to HTTP endpoints with proper routing.

### Acceptance Criteria
| ID | Criterion |
|---|---|
| AC-10 | POST /shorten accepts JSON `{original_url}` and returns 201 with short URL |
| AC-11 | GET /short/:code returns expanded URL (302 redirect) |
| AC-12 | GET /short/:code with invalid code returns 404 |
| AC-13 | Rate limiter blocks after 100 req/min (429) |
| AC-14 | Error responses are consistent (standard error format) |
| AC-15 | All endpoints return appropriate HTTP status codes |

### AI Workflow
- Generate controller skeleton
- Write failing tests for each endpoint
- Implement handler methods
- Verify each endpoint passes

### Quality Gates
- Controller follows naming convention (snake_case)
- No duplicate route names
- Error messages are user-friendly and logged

---

## Stage 5: Authentication & Security Hardening

### Goal
Add security layers without bloating the codebase.

### Acceptance Criteria
| ID | Criterion |
|---|---|
| AC-16 | API keys or JWT authentication required for all endpoints |
| AC-17 | Rate limiting is per-user (not just IP) |
| AC-18 | Input sanitization prevents SQL injection and XSS |
| AC-19 | Short URLs are URL-encoded and validated |
| AC-20 | Logs do not contain sensitive data (passwords, tokens) |
| AC-21 | Health check endpoint `/health` returns status |

### AI Workflow
- Prompt: "Add authentication middleware and rate limiting. Ensure no SQL injection vectors. Use Sinatra's built-in protections."
- Integrate auth into controller (before_action filter)
- Add rate-limiting middleware (e.g., Redis-based or in-memory token bucket)
- Run security scan (Brakeman or similar)

### Quality Gates
- Brakeman report clean (critical/high warnings resolved)
- No console.log of sensitive data
- Authentication fails gracefully (401)

---

## Stage 6: Integration Testing & Edge Cases

### Goal
Verify the full system works together under realistic loads.

### Acceptance Criteria
| ID | Criterion |
|---|---|
| IC-1 | End-to-end: shorten URL → expand → verify redirect → log analytics |
| IC-2 | Concurrent requests don't cause race conditions (unique short URL generation) |
| IC-3 | Rate limiting works correctly under burst traffic |
| IC-4 | Malformed inputs are handled consistently |
| IC-5 | Graceful shutdown doesn't lose in-flight requests |

### AI Workflow
- Write integration tests using a test double for the database (in-memory SQLite or test fixture)
- Simulate concurrent requests with threads
- Validate edge cases (empty URL, extremely long URL, Unicode)

### Quality Gates
- All integration tests pass
- No regression in existing tests
- Performance baseline met (e.g., < 50ms average response)

---

## Stage 7: Final Validation & Code Quality Review

### Goal
Polish the codebase to production readiness.

### Acceptance Criteria
| ID | Criterion |
|---|---|
| QC-1 | Code passes RuboCop with no errors (score ≥ 95) |
| QC-2 | Documentation updated (README, API docs) |
| QC-3 | No TODO/FIXME comments remaining (or justified) |
| QC-4 | Binary size reasonable (~5-10KB for Sinatra app) |
| QC-5 | Deployment-ready: Dockerfile exists, config separated from code |
| QC-6 | CI/CD pipeline sketch (GitHub Actions) includes lint, test, security scan |

### AI Workflow
- Run full linter suite
- Generate final README with usage examples
- Create Dockerfile
- Document deployment steps

### Final Checklist
- [ ] All acceptance criteria (AC-1 through AC-21) satisfied
- [ ] Code quality gates passed
- [ ] No security vulnerabilities (Brakeman/British/etc. clean)
- [ ] Demo-ready: run `rails c` and exercise all endpoints

---

## AI Efficiency Strategy

| Phase | AI Role | Prompt Template |
|-------|---------|-----------------|
| Stage 1 | Brainstorming & spec | "Design a URL shortener API in Sinatra. Define models, routes, and core logic. Focus on clean architecture, TDD, and security. Output a spec doc and a test skeleton." |
| Stage 2 | Skeleton generation | "Create model classes for ShortUrl and User. Write failing unit tests for each. Follow TDD red-green cycle." |
| Stage 3 | Implementation | "Implement URLShortenerService with create, expand, and track methods. Write tests for each method. Ensure tests fail initially." |
| Stage 4 | Controller wiring | "Wire the service to HTTP endpoints. Implement POST /shorten and GET /short/:code. Write tests for each endpoint." |
| Stage 5 | Security hardening | "Add authentication middleware and rate limiting to the API. Prevent SQL injection and XSS. Use Sinatra's built-in protections." |
| Stage 6 | Integration testing | "Write integration tests for the full flow: shorten → expand → analytics. Test concurrency and rate limits." |
| Stage 7 | Polish & review | "Run RuboCop, fix issues. Update README and create Dockerfile. Verify all acceptance criteria are met." |

---

## Time Estimate (Efficient Iteration)
- Stage 1: 1 hour (spec + AC lock)
- Stage 2: 2 hours (models + service tests)
- Stage 3: 3 hours (service implementation + tests)
- Stage 4: 2 hours (controllers + tests)
- Stage 5: 2 hours (auth + security)
- Stage 6: 2 hours (integration + edge cases)
- Stage 7: 1.5 hours (polish + review)

**Total: ~13-14 hours** — achievable in a focused interview preparation session.

---

## Key Principles Demonstrated
1. **TDD at every layer** — tests drive implementation, not the other way around
2. **Security-first** — auth, rate limiting, input validation baked in early
3. **No spaguetti** — clear separation of models, services, controllers
4. **Professional code quality** — linting, documentation, version-controlled config
5. **Efficient AI use** — prompts are specific, iterative, and converge quickly

---

*This plan serves as the blueprint for building a production-quality URL shortener API in Sinatra, demonstrating engineering rigor, TDD discipline, and AI-assisted productivity.*
