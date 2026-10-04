# PRD: Toy Diet AI Agent (Ruby + OpenRouter)

| | |
|---|---|
| Source spec | `AGENTS_toptal.md` |
| Language | Ruby 3.3.7, stdlib only (`net/http`, `json`, `open3`) |
| LLM provider | OpenRouter (`https://openrouter.ai/api/v1`) |
| Data | `https://git.toptal.com/screeners/calories-json/-/raw/main/calories.json` (resolved from `https://topt.al/r6cvQM`) |
| Project folder | `toy_diet_agent/` (flat, run with `ruby agent.rb`) |
| Status | Draft, 2026-10-01 |

---

## 1. Problem statement

Users of a daily diet platform have a long meal log (6,000 records across 20 users) that they can't easily read. They can't see their recent eating pattern at a glance, and nothing helps them plan what to eat next. A command-line agent that answers from *their own data* fixes both problems. It shows the history instantly at no LLM cost, and it uses an LLM with two MCP data tools to recommend varied, healthy meals based on the user's favorites.

## 2. Goals

1. **Instant, free history.** Option 1 prints a user's meal history without calling the LLM.
2. **Grounded recommendations.** Option 2 returns 5 meal recommendations that use only data from the MCP tools for the current USER_ID.
3. **Zero-friction startup.** A first-time run with nothing configured reaches the menu after at most 3 prompts (API key, model, USER_ID). Every later run reaches it with no prompts.
4. **Resilient to LLM failures.** A quota, rate-limit, auth or token-limit error never crashes the process. The user always gets back to the menu.
5. **Cost visibility.** An estimated token count is printed before every LLM call.

## 3. Non-goals

| Non-goal | Why |
|---|---|
| Supporting more than one LLM provider | OpenRouter was chosen, and it already gives access to many models. |
| Free-text chat with the agent | The spec limits interaction to menu options 1, 2, 3 and q. |
| Gem packaging, a Gemfile, Docker or deployment | The spec says to keep it a simple test project. Stdlib covers everything. |
| A full automated test suite | The spec says to avoid full testing scripts. Verification is manual and listed below. |
| Writing to the meal data | The agent reads data only. |
| Using a third-party MCP SDK | No `mcp` gem is installed. A ~60-line stdio JSON-RPC server is enough for 2 tools. |

## 4. Data findings (verified against the live file)

These findings shape the requirements. The live data **does not match** the schema in the spec:

| Field | Spec says | Live data | Handling |
|---|---|---|---|
| `user_id`, `age`, `user_weight` | int / float | **strings** (`"18"`, `"91.88"`) | Coerce with `Integer()`/`Float()` and compare user_id as an integer |
| `favorite` | bool | **string** `"true"`/`"false"` (1,482 true) | Treat `true` or `"true"` as a favorite |
| `price`, `calories`, `weight`, macros | numeric | numeric | Use as is |
| `date_consumed` + `time_consumed` | `yyyy-mm-dd` + `hh:mm` | matches | Sort key is `"#{date} #{time}"`, which sorts correctly as a string |

Records that fail validation (missing keys, bad date or time format) are skipped. The number skipped is reported once when the data loads.

## 5. Personas

- **Diet user**: knows their numeric USER_ID and wants to review and plan their meals from the terminal.
- **Operator**: the person who sets the agent up. Manages the API key and model and runs it from the project folder.

## 6. User stories

Stories are listed in priority order. IDs map to the requirements in section 7.

### Operator

- **US-1** As an operator, I want the agent to find my OpenRouter key and model in the environment, so that I can run it without editing files.
- **US-2** As an operator, I want the agent to fall back to `credentials.json` when env vars are missing, so that my setup survives across shells.
- **US-3** As an operator with nothing configured, I want to be prompted for the key and model once and have them saved, so that I don't have to type them again.
- **US-4** As an operator, I want a non-generative connection check at startup, so that I learn about a bad key or model before I pick an option, without spending tokens.
- **US-5** As an operator, I want the meal data downloaded automatically when it's missing, so that a fresh checkout just works.
- **US-6** As an operator, I want to see the estimated tokens before each LLM call, so that I can keep an eye on cost.

### Diet user

- **US-7** As a diet user, I want to enter my USER_ID once and have it remembered, so that every session starts in my context.
- **US-8** As a diet user, I want to always see the active USER_ID, provider and model above the menu, so that I know whose data and which model I'm using.
- **US-9** As a diet user, I want a quick snapshot of my meal history (newest 3 and oldest 3), so that I can see the range of my log without scrolling.
- **US-10** As a diet user, I want 5 recommendations for the coming days based on my recent favorites, so that my diet stays healthy and varied.
- **US-11** As a diet user, I want to switch to a different USER_ID, so that I can look at another profile without restarting.
- **US-12** As a diet user, I want a clear message when the LLM is out of quota or unavailable, so that I know to try again later and can still use option 1.
- **US-13** As a diet user who enters an unknown USER_ID, I want to be told there are no meals for it, so that I don't get an empty or made-up answer.

## 7. Requirements

### P0: Must have

**R1. Credential resolution** (US-1, US-2, US-3)
- Resolution order: env `API_KEY`/`MODEL`, then `credentials.json` (`{"API_KEY":…, "MODEL":…}`), then a terminal prompt that writes `credentials.json`.
- Each key is resolved on its own. For example, the key can come from the env and the model from the file.
- The key is never printed or logged. When it is typed at the prompt, input is hidden (`IO#noecho`).
- `credentials.json` is listed in `.gitignore`.
- *AC:* Given no env vars and no file, when I run `ruby agent.rb`, then I am prompted for the key and model, `credentials.json` is created, and the next run doesn't prompt.

**R2. Startup LLM check** (US-4, US-12)
- Calls `GET /api/v1/auth/key` (validates the key, no generation). If the model is missing from `GET /api/v1/models`, it warns.
- HTTP 402 or 429 (credits/quota/rate limit): print a warning and continue to the menu.
- Any other failure (401, network error): report it, continue to the menu, and mark the LLM as unavailable. Option 1 still works.

**R3. Data availability** (US-5)
- If `input/meals.json` is missing, create `input/` and download the file, following redirects. If the download fails, print the error and exit, because no option can work without data.

**R4. USER_ID persistence** (US-7, US-11, US-13)
- Read from `USER_ID.md` if present. Otherwise prompt for it, validate it as a positive integer, and write it.
- Option 3 prompts for a new USER_ID, validates it, overwrites `USER_ID.md` and returns to the menu.
- If the USER_ID has no meals, warn but still save it.

**R5. Menu loop** (US-8)
- Every turn prints `USER_ID: <id> | Provider: openrouter | Model: <model>`, then options 1, 2, 3 and q.
- Unknown input prints a hint and shows the menu again. Ctrl-C and EOF exit cleanly.

**R6. Option 1: history snapshot, local only** (US-9)
- Filter by USER_ID and sort by date and time **descending**. Print the first 3 and last 3 lines as `<date_consumed> <time_consumed> <type> <procedence> <name>`.
- If there are 6 meals or fewer, print each one once (no duplicates). If there are more than 6, print a `... (N more)` separator.
- *AC:* no HTTP request is made to OpenRouter.

**R7. MCP server with 2 tools** (US-10)
- `mcp_server.rb` speaks MCP over stdio using newline-delimited JSON-RPC 2.0 and supports `initialize`, `tools/list` and `tools/call`.
- `get_recent_favorites(user_id)`: the user's meals where favorite is true, sorted by date and time descending, limited to **30**. Each record is compact: `date, time, type, name, calories, protein, carbs, fat, price`.
- `get_monthly_summary(user_id)`: groups by `yyyy-mm` and returns `{month, total_calories, meal_count, highest_price:{name,price,date}, lowest_price:{name,price,date}}`.
- The client (`mcp_client.rb`) starts the server **lazily** on the first use of option 2 and reuses it for later calls.

**R8. Option 2: LLM tool loop** (US-10, US-6, US-12)
- Before anything else, check that the LLM is available. If it isn't, print a clean error and return to the menu.
- The system prompt lists the tools from `tools/list`. It requires JSON-only replies: `{"action":"tool","name":…,"arguments":{…}}` or `{"action":"final","answer":"…"}`. It tells the model to answer **only from tool data** for the current USER_ID.
- The user message is the option 2 request text plus the USER_ID.
- Loop: estimate tokens (chars / 4) and print them, call `POST /api/v1/chat/completions`, then parse the reply. A tool action runs through MCP and its compact JSON result is appended. A final action prints the answer. The loop stops after **6 iterations**.
- If the reply can't be parsed (it isn't JSON or has an unknown action), print `Could not parse LLM response` along with the **raw response**, then return to the menu.

**R9. Error handling for LLM calls** (US-12)
- 402 or 429: `LLM quota/rate limit reached, try later.` 401: `Invalid API key.` Context-length errors (400 or 413 with "context"/"token" in the message): `Request too large.` Network or timeout errors: a short message. All of them return to the menu, and **none is treated as success**.
- HTTP timeouts: 10s to open, 60s to read.

### P1: Nice to have
- **R10.** Accept `OPENROUTER_API_KEY` as an alias when `API_KEY` is unset. *(The operator's env already has `OPENROUTER_API_KEY`, verified valid, and `API_KEY` is unset. Without the alias, the first run prompts for a key that is already available.)*
- **R11.** Fall back to a default `MODEL` in the prompt (for example `openai/gpt-4o-mini`) when the operator just presses Enter.
- **R12.** `README.md` with run instructions and file descriptions.

### P2: Future considerations
- A pluggable provider adapter in `llm.rb`, so that other providers could be added later.
- Native OpenRouter `tools` (function calling) in place of the JSON-reply protocol.
- Caching the parsed meals between option 2 calls.

## 8. Success metrics (manual acceptance run)

| Metric | Target |
|---|---|
| Option 1 latency | < 1 s, with 0 LLM requests |
| Option 2 completes for a valid user | Returns exactly 5 recommendations in ≤ 6 iterations |
| Recommendations are grounded | Every recommended meal is a meal name that appears in the tool output, or is clearly described as a variation of one |
| Startup with nothing configured | ≤ 3 prompts before the menu |
| Failure injection (bad key, unset network, 429) | 0 crashes, and the user returns to the menu every time |
| Token print | Shown before 100% of LLM calls |

## 9. Verification plan

1. `ruby mcp_server.rb` with piped `initialize`, `tools/list` and both `tools/call` lines. Check that the shapes are correct and favorites ≤ 30.
2. `ruby agent.rb` with option 1 for user 18. Check the order and format, and test a user with ≤ 6 meals if one exists.
3. Option 2 with a valid key. Check the token print, the tool calls and the 5 recommendations.
4. A bad `API_KEY` in the env: the startup check reports it, option 1 works, and option 2 shows a clean error.
5. Delete `input/meals.json` and check that it is downloaded again. Delete `USER_ID.md` and check that the prompt appears.

## 10. Open questions

| # | Question | Owner | Blocking? |
|---|---|---|---|
| Q1 | Which OpenRouter model should be the default (`MODEL` is unset)? Options are a cheap paid model like `openai/gpt-4o-mini` or a `:free` model, which has strict rate limits. | Operator | Yes, before the option 2 test |
| Q2 | Should we accept the existing `OPENROUTER_API_KEY` env var (R10), or should the operator export `API_KEY` / use `credentials.json`, as the spec says? | Operator | No (the default is to accept it) |
| Q3 | Does "recent favorites" mean the 30 most recent favorites overall (as specified), or only those in the last N days? | Stakeholder | No (the default is as specified) |
| Q4 | The project folder location is `toy_diet_agent/` at the repo root. Should it be its own git repo, as the other projects are? | Operator | No |

## 11. Timeline

This is a single time-boxed screener build with no external dependencies beyond OpenRouter and the data URL, which were both verified reachable on 2026-10-01. Suggested order: MCP server and data, then option 1, then credentials and startup, then the LLM client and option 2, then README.
