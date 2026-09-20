# Devcontainer bootstrap architecture — staged migration

## Context

This devcontainer works, but every dependency update costs a full rebuild, the bootstrap has
defects that can stop the container starting at all, and one startup path is actively writing
PostgreSQL data files into iCloud Drive.

Three causes, in order of severity.

**The Ruby compile dominates rebuild cost.** `.devcontainer/Dockerfile` runs
`rvm install ${RUBY_VERSION}`, compiling from source. Six `ARG`/`ENV` declarations sit above that
layer, so changing any one of them — including `DATABASE_PASSWORD` — invalidates it. Bumping Node
recompiles Ruby, although the two are unrelated.

**Versions are declared in several places with nothing enforcing agreement.** Ruby 3.3.7 appears
four times. PostgreSQL 15 appears three times as a variable and eight more as a hardcoded literal
path across two near-identical maintenance scripts.

**PostgreSQL runs inside the app container under a custom `ENTRYPOINT`.** That entrypoint runs
`set -e` as PID 1, so any service script exiting non-zero kills the container before a single
lifecycle hook runs. `CONTAINER_DOCUMENTATION/` records a corruption incident from this design.

Intended outcome: dependency updates that mostly need no rebuild, one place per version, and a
database whose lifecycle is independent of the app image.

## Assumptions

One entry per place your words admitted more than one reading.

- **"optimally" in the original loop prompt**
  - You said: "Your goal is to get the devcontainer running optimally."
  - I read it as: the container starts clean, every declared tool is present, and updating a
    dependency does not require a full rebuild.
  - I rejected: runtime performance tuning (shared memory, `fsync`, build parallelism). Nothing in
    the session pointed at speed of the running container.
  - If I'm wrong: Phases 2 through 4 are the wrong work entirely, and the plan becomes a
    PostgreSQL and Docker resource-tuning exercise.

- **"least possible downtime"**
  - You said: "dependencies are easy to update with the least possible downtime"
  - I read it as: downtime of your own development session — minutes lost to a rebuild before you
    can type again.
  - I rejected: availability of a deployed service. Nothing here is deployed.
  - If I'm wrong: the Compose phase needs health-gated rolling restarts, which this plan does not
    contain.

- **Whose decisions the newest items are**
  - Phase 0, the `bin/dev` replacement, the Ofelia backup sidecar and the dry-run migration were
    added by a plan-review pass, not by you. The four items under "Decisions taken by the owner"
    below are yours, quoted from your AskUserQuestion answers.
  - Three of those four review additions are mechanisms you never named, which is planning.md
    trigger 2. They are pulled out into **Open** rather than left in the phases.
  - If I'm wrong about any of them being wanted: delete the item; no other part of the plan
    depends on it.

## Decisions taken by the owner

Settled. The plan builds to them.

1. **`mise` replaces RVM and NVM.** It downloads precompiled Ruby binaries for linux arm64 by
   default. Accepted cost: RVM gemsets are lost.
2. **PostgreSQL moves to its own Docker Compose service.**
3. **Local builds only.** No CI, no GHCR, no registry push.
4. **Staged, cleanup first.** Each phase ships alone.
5. **`run_dev_stack.sh` is retired via `bin/dev`.** Add `bin/dev` + `Procfile.dev` to the four
   projects that lack one, then delete the script.
6. **`projects_own/[DEPRECATED-DELETE]the_outperformer_os` is deleted in Phase 1.**
7. **Phase 0 builds a full `.devcontainer-next`**, settling the networking and Postgres-UID
   questions before Phase 4 rather than during it.
8. **An `ofelia` scheduler is added after Phase 4 is stable**, running a daily logical dump.
9. **The `bundler:2.3.26` pin is dropped**, in Phase 3, where that Dockerfile line is rewritten
   anyway. You accepted the recommendation rather than choosing between the two options, so the
   reasoning is recorded under "Answered" item 5.

## Hard constraint — iCloud Drive

The repo sits under `Library/Mobile Documents/com~apple~CloudDocs`. iCloud evicts unsynced files.
PostgreSQL data, gem trees and the mise tool directory must live on named Docker volumes, never a
repo bind mount. A bind mount over the gem directory already hid the image's gems once and made
`rails` vanish at runtime.

---

## Three defects found during planning that are not in the original brief

All three verified directly. Two change the plan.

### D1 — Every container start stops PostgreSQL and copies 38 MB of raw data into iCloud

`init-postgresql.sh:297-301` calls `backup-postgresql.sh create` unless `/tmp/backup_created`
exists. `/tmp` is ephemeral, so that marker is gone on every start. `create_backup()` runs
`pg_ctl stop -m fast`, then copies the whole `PGDATA` into `/var/lib/postgresql-backup` — which is
the `.DB_backups` bind mount, on iCloud.

On disk right now:

```
.DB_backups/data_20260918_194753   38M   PG_VERSION=15
.DB_backups/data_20260918_195540   38M   PG_VERSION=15
```

Two full cluster copies, written seven minutes apart today. This violates the iCloud constraint
via the project's own startup path, and it stops the database mid-start.

### D2 — Three of `maintenance.sh`'s six commands can never work

`services/maintenance.sh:19` reads:

```bash
readonly BACKUP_SCRIPT="./scripts/services/backup-postgresql.sh"
```

A relative path. The script runs from `/usr/local/bin/devcontainer-scripts/services/`, so `backup`,
`list-backups` and `cleanup` all print "Backup script not found" and exit 1. `CONTAINER_DOCUMENTATION`
instructs people to invoke it via `docker exec`, which always fails.

### D3 — Seven projects pin a Ruby the image does not contain

The image installs Ruby 3.3.7 and Node 22, only. Actual pins:

| Version | Projects |
|---|---|
| Ruby `3.2.0` | `interview_scheduler`, `products`, `quick_wins`, `quick_wins_vAPI`, `secure_notes`, `template` |
| Ruby `3.3.0` | `forem` |
| Ruby `3.3.7` | `construction-manager`, `inertia-js`, `sales_agent`, `view_component`, `[DEPRECATED-DELETE]…` |
| Node `18.20.6` | `products`, `quick_wins`, `quick_wins_vAPI`, `secure_notes`, `template` |
| Node `20` / `22` | `forem` (`.nvmrc`), `construction-manager` |

Seven projects cannot run on the image's Ruby today. This is a strong independent argument for
mise, and it means Phase 3 installs four Rubies and three Nodes, not one of each.

Eight `.ruby-version` files use RVM's `ruby-3.2.0` prefix form rather than a bare version.

---

## Phase 0 — Prototyping & Verification

**Goal.** Settle every assumption Phases 3 and 4 rest on, in a throwaway environment, before any
file under `.devcontainer/` changes.

`.devcontainer-next/` is a scratch directory holding its own `devcontainer.json`, `Dockerfile` and
`compose.yaml`. It is never attached to by VS Code as the project's container and it is deleted at
the end of this phase. Nothing in it is merged; it answers questions, it does not become Phase 3.

**Why a whole second config rather than experiments in the running container** (your decision): the
mise questions could be answered in place, but the two Phase 4 questions cannot. Both depend on how
containers reach each other and how the stock Postgres image behaves, and Phase 4 is the phase with
the irreversible step. Answering them here costs a build and moves that risk out of the phase that
touches your data.

**Q1 — mise, Ruby.** Does `mise install ruby@3.2.0` fetch a precompiled linux-arm64 binary, or fall
back to a ruby-build compile? Time both `3.2.0` and `3.3.7`. *Settles:* whether Phase 3's central
claim — no more Ruby compiles — is true on this machine. If it compiles, Phase 3's value drops to
per-project version switching alone and the phase is worth re-costing.

**Q2 — mise, the `ruby-` prefix.** Eight `.ruby-version` files read `ruby-3.2.0`, RVM's form, not a
bare `3.2.0`. Does mise parse it with `idiomatic_version_file_enable_tools = ["ruby", "node"]` set?
*Settles:* whether Phase 3 also has to rewrite eight files, and whether that setting works from a
project-level `mise.toml` or only the global one.

**Q3 — Postgres UID.** Ubuntu's `postgresql-15` package and the official `postgres:15` image use
different UIDs for the `postgres` user. *Settles:* whether Phase 4's restore can read anything
written by the current cluster, and it is the first check on the dump-versus-remount decision.

**Q4 — networking without `--network=host`.** Start a two-service `compose.yaml` in
`.devcontainer-next`. Confirm: `db` resolves by service name from `app`; `ports:` on `db` makes
5432 reachable from macOS; and a Rails server bound to `0.0.0.0` in `app` is reachable from the
host through `forwardPorts`. *Settles:* whether dropping `--network=host` costs anything you use.
If any of the three fails, Phase 4's `devcontainer.json` section is wrong and needs redesigning
before, not during, the migration.

**Exit condition.** All four answered and written into this file under Verified. Then delete
`.devcontainer-next/`.

---

## Phase 1 — Cleanup, no architecture change

**Goal.** Make the container start deterministically, fail loudly, and stop writing database files
into iCloud.

### Delete

| File | Why |
|---|---|
| `.devcontainer/scripts/maintenance.sh` | Dead — not `COPY`'d. Two copies is how the 8 hardcoded paths got duplicated. |
| `.devcontainer/scripts/services/init-mongodb.sh` | Doubly dead — disabled via `DISABLED_SERVICES`. |
| `stop-services.sh` heredoc | Never invoked. `shutdownAction: stopContainer` sends SIGTERM to PID 1. |
| `projects_own/[DEPRECATED-DELETE]the_outperformer_os` | Your decision. Removes one `.ruby-gemset` and one bundle from the Phase 3 migration. |
| `run_dev_stack.sh` | Your decision, after the four `bin/dev` files below exist. 379 lines, no callers — a grep across every `.md`, `.json` and `.sh` in the repo returns only its own two comment lines. |

### Retire `run_dev_stack.sh` — four projects, then delete

Eight projects already have `bin/dev` and `Procfile.dev`. Four do not, and they are exactly the
ones the script serves:

| Project | Has `package.json` | `Procfile.dev` needs |
|---|---|---|
| `projects_own/quick_wins` | yes | `web:` + `js:` |
| `projects_own/secure_notes` | yes | `web:` + `js:` |
| `projects_own/template` | yes | `web:` + `js:` |
| `projects_own/quick_wins_vAPI` | **no** | `web:` only |

Per project: a two-line `bin/dev` matching the eight that exist, a `Procfile.dev`, and `foreman` in
the development group of its `Gemfile`. Copy the shape from
`projects_own/construction-manager/bin/dev` rather than writing a new one.

Delete `run_dev_stack.sh` only once all four start cleanly. Doing it in the other order leaves those
four with no start command.

### Move admin tools out of the orchestrator's path

`backup-postgresql.sh` and `maintenance.sh` are admin tools, not initializers. They survive the
glob only because of no-command guards.

- `scripts/services/backup-postgresql.sh` → `scripts/pg-backup.sh`
- `scripts/services/maintenance.sh` → `scripts/pg-maintenance.sh`

`services/` then holds exactly one file: `init-postgresql.sh`. Dockerfile `COPY` becomes explicit
per-file lines rather than a directory copy.

### Rewrite `start-services.sh`

1. **Drop `set -e`.** It is PID 1; a failing service currently kills the container before any hook
   runs, which is why a broken database looked like a broken devcontainer.
2. **Replace the glob with an explicit list**: `SERVICES=( init-postgresql.sh )`. No file can run
   by accident.
3. **Record failures to `/run/devcontainer/init-failures`, then start anyway.** `/run` is tmpfs,
   cleared per start. `postStartCommand.sh` reads it and exits non-zero when non-empty — that is
   the visible failure.

### Fix D1 — remove the auto-backup

Delete the `backup-postgresql.sh create` block in `init-postgresql.sh` `verify_connection()`.
Backups become explicit via `pg-backup.sh create`.

**Trade-off.** Lost: an automatic copy before each session. Gained: no database stop mid-startup,
and no 38 MB of Postgres internals into iCloud per start. Phase 4 replaces it with a logical dump.

Delete the two existing `.DB_backups/data_*` directories **only after** Phase 4's dump is verified.
They are the only physical fallback that exists today.

### Fix D2 and the hardcoded paths

- `BACKUP_SCRIPT` → `"$(dirname "$(readlink -f "$0")")/pg-backup.sh"`.
- Replace the 4 hardcoded `/usr/lib/postgresql/15/bin/...` paths with
  `PG_BIN="/usr/lib/postgresql/${POSTGRES_VERSION:-15}/bin"`.
- Normalise the two bare `pg_ctl` calls in `pg-backup.sh` `restore_backup` to `${PG_BIN}` too.

### De-duplicate `check_tool` into `.devcontainer/lib/common.sh`

`check_tool` is defined byte-identically in `postCreateCommand.sh` and `verify-environment.sh`, and
their tool lists have already diverged — npm and yarn in one, not the other.
`postAttachCommand.sh` hand-rolls a third variant.

**Why the bind mount, not the image.** All four callers run from the bind-mounted workspace. A
`COPY`'d shared file would need a rebuild on every edit while its callers would not.

`common.sh` holds `check_tool`, the log helpers, and one canonical `DEV_TOOLS` list.

**Deliberate exception:** the image-side scripts (`init-postgresql.sh`, `pg-backup.sh`,
`pg-maintenance.sh`) do *not* source it. They must work when `/workspace` is unmounted, e.g. under
`docker exec`. They keep local log helpers. Small, intentional duplication.

### Make `verify-environment.sh` able to fail

1. Add a failure counter; end with `[ "$FAILURES" -eq 0 ] || exit 1`. Today the last statement is
   an `echo`, so it always exits 0.
2. Move the `createdb` side effect behind an explicit `--create-missing-db` flag. A script named
   `verify` must not create a database.
3. `postStartCommand.sh` must check the exit code, plus `/run/devcontainer/init-failures`.

`postCreateCommand.sh` stays exit-0 on missing tools: `waitFor: postCreateCommand` means a non-zero
there blocks attach entirely, and you need to attach to debug.

### Documentation

Fix `VERIFICATION.md` (wrong script named for `verify-environment.sh`, stale line 133, "Rails
8.x.x" vs pinned 7.2.2, stale postAttach claim) and repoint the ~15
`services/maintenance.sh` references across `CONTAINER_DOCUMENTATION/` to `pg-maintenance.sh`.

### Verify

Automate these checks by creating `scripts/test-migration.sh`:

```bash
#!/bin/bash
set -e
docker exec <ctr> cat /run/devcontainer/init-failures              # empty
docker exec <ctr> ls /usr/local/bin/devcontainer-scripts/services/ # only init-postgresql.sh
docker exec <ctr> /usr/local/bin/devcontainer-scripts/pg-maintenance.sh list-backups
ls .DB_backups/                                                    # NO new data_* after restart
grep -rn "/usr/lib/postgresql/15/bin" .devcontainer/               # zero hits
# Negative test:
docker exec <ctr> sudo -u postgres ${PG_BIN}/pg_ctl -D /var/lib/postgresql-data stop -m fast
./verify-environment.sh && exit 1 || echo "verify-environment failed successfully"
```

**Rollback.** `git revert`. No volume, image layer or database touched.

---

## Phase 2 — One source of truth for versions

**Goal.** Ruby and Node in one file; drift elsewhere fails a check.

### The honest limitation, stated up front

`devcontainer.json` cannot read a TOML file. It has no interpolation beyond `${localEnv:…}`,
`${containerEnv:…}` and `${localWorkspaceFolder}`. **Phase 2 does not eliminate duplication** — it
reduces four copies of Ruby to two and makes disagreement fail.

### Files created

- **`mise.toml`** (repo root) — `[tools]` ruby + node, and
  `idiomatic_version_file_enable_tools = ["ruby", "node"]`.
- **`.devcontainer/.env`** — `POSTGRES_VERSION`, `DATABASE_USERNAME`, `DATABASE_PASSWORD`,
  `RAILS_VERSION`. Inert in Phase 2; load-bearing in Phase 4, where Compose reads it natively.
  Creating it now keeps the Phase 4 diff small.
- **`.devcontainer/lib/check-versions.sh`** — compares `mise.toml` against the *running* toolchain,
  not against another config file. Called from `postStartCommand.sh`.

### How Ruby and Node reach zero duplication

Stop installing them at build time. The Dockerfile installs only the mise binary;
`postCreateCommand.sh` runs `mise install`. Then no ARG, build arg or `remoteEnv` entry names a
Ruby or Node version anywhere.

**Cost:** container creation needs network and takes as long as mise's downloads. Version errors
surface at create time, not build time. **Benefit:** one file, and the stale-volume trap in Phase 3
disappears entirely.

Postgres cannot join this scheme — apt package in Phase 2, image tag in Phase 4. It stays in `.env`.

**End state after Phase 4: two files.** `mise.toml` for runtimes, `.env` for Postgres and
credentials. No third.

### Verify

Flip `ruby` in `mise.toml` to a different version; `check-versions.sh` must exit 1. Restore.

**Rollback.** Delete the three new files and the call site.

---

## Phase 3 — `mise` replaces RVM and NVM

**Goal.** One version manager, per-project Ruby and Node with no rebuild, per-project gem isolation
without gemsets.

> ⚠️ **Data hazard mitigated.** This phase deletes the `rvm-gems` volume.
> Before starting, run `gem list --local > /workspace/.gems-cache/pre-migration-gems.txt` in the current container. 
> Create a script `scripts/restore-gems.sh` to read this list and `mise exec -- gem install` missing gems into the new `BUNDLE_PATH` volume, ensuring zero data loss.

### Dockerfile

**Deleted:** the NVM block, the RVM block, the `SHELL ["/bin/bash","-lc"]` + `rvm install` +
`gem install` layer, the RVM/NVM `ENV PATH`, `~/.rvmrc`, `/etc/profile.d/nvm.sh`,
`/etc/profile.d/rvm.sh`, the `.bashrc` RVM/NVM heredoc, and `ARG RUBY_VERSION` / `ARG NODE_VERSION`.

**Kept:** `~/.bash_profile` sourcing `~/.bashrc`, and the aliases/PS1 block in
`postCreateCommand.sh`.

**Added:** mise to `/usr/local/bin` via `MISE_INSTALL_PATH`, plus `/etc/mise/config.toml` carrying
the idiomatic-version-file setting system-wide, so it survives container recreation.

### The global CLIs need their own Node — recommended decision

`corepack`/`yarn`, `@vue/cli`, `claude` and `pi` all currently install under NVM's Node. With no
build-time Node they would move to `postCreateCommand.sh` and re-download ~397 MB on every container
creation — undoing commit `1f8d667`.

**Install one Node via apt purely to host the global CLIs, and let mise own per-project Node.**
The CLIs are tools, not project dependencies; coupling them to a project's Node version is wrong.
Costs one apt package, adds zero version duplication, because that Node matches nothing.

### Activation — shims, not `mise activate`

Set `PATH` to `/home/vscode/.local/share/mise/shims:${containerEnv:PATH}` in `remoteEnv`.

**Shims win** because they work where nothing sources a shell file: `bash -c`, VS Code tasks, the
Ruby LSP spawning a process, `docker exec`. The current design needs `#!/bin/bash -l` on every
script precisely because it uses PATH activation.

**Shims lose** on two documented points: `[env]` vars only apply when a shim is invoked, and
`which ruby` shows the shim path. Neither matters here — there is no `[env]` block, and
`mise which ruby` gives the real path.

Do **not** combine shims with `eval "$(mise activate bash)"` until tested.

### The gemset replacement — one shared `BUNDLE_PATH` on a named volume

Three candidates considered:

- **Relative `BUNDLE_PATH=vendor/bundle`** — rejected. Puts every gem tree on the iCloud bind mount.
- **Per-project `bundle config set --local path`** — works, but touches every project, now and
  future.
- **One absolute `BUNDLE_PATH` into a named volume** — **recommended**.

**Why this is real isolation.** Bundler installs into `$BUNDLE_PATH/ruby/<ABI>/gems/`. The ABI
directory separates Ruby 3.2.0 from 3.3.7 automatically. Within one Ruby, `bundle exec` builds its
load path from that project's `Gemfile.lock` alone — another project's gem is on disk but not on
the load path. That is what gemsets provided. Only disk-level separation is lost, and nothing
depends on it.

`BUNDLE_PATH=/home/vscode/.bundle-gems` in `remoteEnv`, backed by a `bundle-gems` named volume.

**Per-project work is small.** Only `inertia-js` and the deprecated project have a `.bundle/`
directory, and **both `.bundle/config` files are empty** — no conflicting local `path` setting
anywhere. Per project: delete `.ruby-gemset`, then `bundle install` once.

### `.ruby-version` files

- **Delete** root `.ruby-version`, root `.ruby-gemset`, and `projects_own/.ruby-version` /
  `.ruby-gemset`. The intermediate pair silently overrides root for every project lacking its own.
- **Keep** per-project `.ruby-version`, `.node-version`, `.nvmrc`. Each is its project's only
  declaration, they are read by tools outside this container, and those directories are gitignored
  so conversion buys nothing.

### Volumes

| Old | New | Contents |
|---|---|---|
| `rvm-gems` → `/home/vscode/.rvm/gems` | `mise-data` → `/home/vscode/.local/share/mise` | Toolchains, plus each Ruby's `GEM_HOME` where `rails` lives for `rails new` |
| — | `bundle-gems` → `/home/vscode/.bundle-gems` | All projects' bundled gems, ABI-separated |

**The trap worth knowing.** A named volume seeds from the image only when empty. Baking a Ruby into
the image *and* mounting `mise-data` means a stale volume shadows the new image content and version
bumps silently do nothing — the `rails`-vanished failure in reverse. **Phase 2's decision to install
nothing at build time removes this risk**, because there is nothing to shadow, and `mise install`
repairs the volume from `mise.toml`.

### Changing a version with no rebuild — the primary goal

```bash
cd /workspace/projects_own/quick_wins && mise use ruby@3.2.9   # installs and activates now
cd /workspace && mise use ruby@3.4.1                           # workspace default
```

**Persists** across recreation: `mise.toml` and `.ruby-version` edits (bind mount), toolchains
(`mise-data`), gems (`bundle-gems`).
**Does not persist:** a toolchain from bare `mise install ruby@X` never written to a config — always
use `mise use`; hand edits to `~/.bashrc`, since `/home/vscode` is not a volume.

### `gem install bundler rails` and the build assertion

The build-time layer is deleted whole and moves to `postCreateCommand.sh`:

```bash
mise exec -- gem install bundler rails:"${RAILS_VERSION}"
mise exec -- rails --version || exit 1
```

**Before:** `.devcontainer/Dockerfile:109` reads
`gem install bundler:2.3.26 rails:${RAILS_VERSION}`.
**After:** `bundler` with no version, per decision 9.
**Why:** `bundle --version` in the running container reports 2.5.22, not the pinned 2.3.26, so the
pin installs a gem that nothing then uses. Bundler resolves itself from each project's
`Gemfile.lock`, which is the mechanism that should decide the version. The `rails` pin stays —
`RAILS_VERSION` still controls what `rails new` scaffolds.

One consequence worth expecting: a project whose `Gemfile.lock` names a Bundler that is not
installed makes `bundle install` fetch it on first use. That is Bundler's normal behaviour and it
needs network on that first run.

**Lost:** the assertion no longer fails the *build*, only `postCreateCommand` — a weaker signal,
since the image is already cached.
**Gained:** no Ruby compile, and the assertion now runs against the *actual* runtime including
volume mounts. The original incident was `rails` present in the image and invisible at runtime; a
build-time assertion cannot catch that, a `postCreate` one can. Better test, worse-signalled place.

### Verify

```bash
which ruby          # .../mise/shims/ruby
bash -c 'ruby --version'                    # non-login, non-interactive — the shim test
docker exec <ctr> bash -c 'ruby --version'  # no shell init at all
ls /etc/profile.d/                          # no rvm.sh, no nvm.sh
cd projects_own/products && ruby --version  # expect 3.2.x, not 3.3.7
ls /home/vscode/.bundle-gems/ruby/          # expect ABI dirs 3.2.0/ and 3.3.0/
find . -name .ruby-gemset -not -path "./.git/*"   # zero
cd /workspace && mise use ruby@3.4.1 && ruby --version   # no rebuild; then git checkout mise.toml
grep -rn "bundler:2.3.26" .devcontainer/                 # zero hits
bundle --version                                         # whatever the active Ruby ships; no pin claimed
```

**Rollback.** `git revert` and rebuild. `rvm-gems` must still exist.

---

## Phase 4 — PostgreSQL as a Compose service

**Goal.** Move the database to `postgres:15`, delete roughly 1,195 lines of startup scripting, and
keep the data.

> ⚠️ **The existing `postgres-data` volume is NOT reusable by the stock image. Dump before changing
> any file. The ordering below is not negotiable.**

### `compose.yaml`

New `.devcontainer/compose.yaml` with `app` (built from the existing Dockerfile,
`command: sleep infinity`, `depends_on: db: condition: service_healthy`) and `db`
(`postgres:${POSTGRES_VERSION}`, `POSTGRES_USER`/`POSTGRES_PASSWORD`/`POSTGRES_DB`, a `pg_isready`
healthcheck, `ports: 5432`). Compose reads `.devcontainer/.env` automatically.

Data goes to a **new** `postgres-data-v2` volume. The old one is left untouched for rollback.

`ports: 5432` on `db` is what keeps TablePlus and `psql` on macOS working — `forwardPorts` applies
only to the `service` container, which is `app`.

### `devcontainer.json`

**Removed:** `build`, `runArgs`, `workspaceMount`, the entire `mounts` array, and the
`RUBY_VERSION`/`NODE_VERSION`/`POSTGRES_VERSION`/`DATABASE_URL`/`DISABLED_SERVICES` `remoteEnv`
entries. Per the containers.dev reference these are image-specific and do not apply to Compose.

**Added:** `dockerComposeFile`, `service: app`, `workspaceFolder: /workspace` (no useful default
under Compose, and `pg-maintenance.sh` plus `root.code-workspace` hardcode it),
`shutdownAction: stopCompose`, and the mise shims `PATH`.

**`--network=host` must be dropped — plainly.** Compose has no `runArgs`. The nearest equivalent,
`network_mode: host`, breaks Compose service-name DNS, so `db` would stop resolving. You cannot have
both host networking and the `db` hostname.

Concrete consequence: Rails and Vite must bind `0.0.0.0`, not `127.0.0.1`. That means `-b 0.0.0.0`
on the `web:` line of every `Procfile.dev`, including the four Phase 1 creates.

### Every file hardcoding `localhost` for Postgres

Found by search, not guessed:

| File | Change |
|---|---|
| `Dockerfile` (2 lines) | Delete `ENV DATABASE_URL=…@localhost:5432/`; it moves to `compose.yaml` |
| `verify-environment.sh` (6 lines) | `-h localhost` → `-h "${POSTGRES_HOST:-db}"`; keep a separate "from macOS" display line |
| `run_dev_stack.sh` (1 line) | same substitution |
| `VERIFICATION.md`, `Quick-Reference-Guide.md` | documented connection strings |
| `init-postgresql.sh` (4 lines) | moot — file deleted |
| `projects_open_source/sales_agent/config/database.yml` | **no edit** — already `ENV.fetch("POSTGRES_HOST") { "localhost" }`, and Compose sets `POSTGRES_HOST: db` |

Nine projects read `DATABASE_URL` from the environment and inherit the new host automatically.

### Fate of the existing scripting

`init-postgresql.sh` (361 lines), `start-services.sh` (40), and the `ENTRYPOINT`/`CMD` are
**deleted**, replaced by the stock image's entrypoint plus the Compose healthcheck.
`pg-backup.sh` (285) and `pg-maintenance.sh` (250) shrink to roughly 60 and 40 lines.

**The capability genuinely lost.** `check_data_integrity()` and `create_backup()` implement
corruption detection followed by automatic physical backup and clean reinitialisation. **The stock
image has no equivalent.** A damaged data directory means a failed healthcheck and a manual restore
from the most recent dump.

**Both sides.** *Against:* that logic was built after a real incident, and it is being discarded.
*For:* much of the corruption risk came from the very setup being removed — `pg_ctl` under a
`set -e` PID 1, a cluster stopped mid-startup for a physical copy, and SIGTERM to PID 1 with no
graceful stop. The stock image runs Postgres **as** PID 1, so Docker's SIGTERM reaches the postmaster
directly and triggers a clean shutdown. Fewer corruption events beats better corruption recovery.

Keep password auth. `POSTGRES_HOST_AUTH_METHOD=trust` would trust every container on the network.

### Backups

The `pg_ctl`-stop-and-copy logic is discarded with `init-postgresql.sh`. `pg-backup.sh` becomes a
logical dump run over the network, which needs no database stop:

```bash
pg_dump -h db -U dbuser -Fc dbuser > <target>/dump_$(date +%Y%m%d_%H%M%S).dump
```

Once Phase 4 is stable, an `ofelia` scheduler service is added to `compose.yaml` to run that same
command daily. `ofelia` is a small cron container that executes commands inside other Compose
services, configured through labels on the `db` service.

**It is deliberately not part of Phase 4.** Phase 4 is the phase with irreversible steps; adding a
fourth container to the same change makes a failure harder to attribute. Until the scheduler lands
there is no automatic backup at all, so run `pg-backup.sh create` by hand during that window.

The dump target must not be `.DB_backups`, which is on iCloud. Use a named volume, or a path
outside the repo.

### Migrating the data — Dry Run Strategy

Instead of blindly deleting the volume, use a dry-run migration to guarantee success:

1. **BEFORE any Phase 4 file change**:
   `docker exec <ctr> sudo -u postgres pg_dumpall --clean --if-exists > /tmp/pre-compose-dumpall.sql`
   `cp /tmp/pre-compose-dumpall.sql ~/Desktop/` (OFF iCloud)
2. **Record what correct looks like**:
   `docker exec <ctr> psql -U dbuser -d dbuser -c "SELECT relname, n_live_tup FROM pg_stat_user_tables ORDER BY relname;" > /tmp/old-counts.txt`
3. **Configure the Dry Run**:
   In Phase 4 `compose.yaml`, map the new DB to a different port temporarily (e.g., `5433:5432`) and run it alongside the old setup.
4. **Restore and Verify**:
   `psql -h localhost -p 5433 -U dbuser -d postgres -f /tmp/pre-compose-dumpall.sql`
   Run the row count query against port 5433. Automate this via a `scripts/verify-db-counts.rb` script to assert the counts match `/tmp/old-counts.txt`.
5. **Finalize**:
   Once verification passes, flip `compose.yaml` back to `5432` and safely shut down/delete the old `postgres-data` volume.

### `verify-environment.sh` Postgres checks

`pgrep -x postgres` can never see a process in another container — delete it, along with the
`sudo service postgresql start` advice, which was already wrong. Replace with `pg_isready -h
"${POSTGRES_HOST:-db}"` plus an authentication probe. `pg_isready` is a network client and works
across containers unchanged.

Keep `postgresql-client-15` and `libpq-dev` in the app image; drop the `postgresql-15` server
packages, which also shrinks the image.

### Verify

```bash
docker compose -f .devcontainer/compose.yaml config    # validates .env interpolation
env | grep DATABASE_URL                                # expect @db:5432
psql -h db -U dbuser -d dbuser -c 'SELECT version();'
psql -h localhost -U dbuser -d dbuser -c 'SELECT 1;'   # from macOS — proves ports: works
docker compose … down && docker compose … up -d && psql -h db -U dbuser -d dbuser -c '\dt'
docker compose … stop db && ./verify-environment.sh; echo "exit=$?"   # expect 1
```

**Rollback.** `git revert`, rebuild against the untouched `postgres-data`. Dump
`postgres-data-v2` first if it holds newer data. **Deleting `postgres-data` is the single riskiest
command in this plan — leave it at least a week.**

---

## Ordering hazards

| Hazard | Phase | Consequence |
|---|---|---|
| Delete `rvm-gems` before Phase 3 is proven | 3 | Runtime-installed gems absent from any lockfile are unrecoverable |
| Delete `postgres-data` before verifying the restore | 4 | Total, irreversible database loss |
| Change `compose.yaml` before running `pg_dumpall` | 4 | Old cluster still on disk but recovery needs a manual container |
| Write the dump only into `.DB_backups` | 4 | iCloud can evict it |
| Delete `.DB_backups/data_*` before Phase 4 | 1 | Loses the only pre-migration physical fallback |
| Mount `mise-data` while also baking Ruby into the image | 3 | Stale volume shadows the image; version bumps silently do nothing |

---

## Open

**Nothing needs you.** Items 1 through 5 were answered on 2026-09-18 and are recorded under
"Decisions taken by the owner". The briefings are kept below.

---

## Answered — kept for the record

### 5. The `bundler:2.3.26` pin in the Dockerfile does not take effect — drop it or fix it? → **5a**

**What this is.** `.devcontainer/Dockerfile:109` runs `gem install bundler:2.3.26`, but
`bundle --version` in the running container reports 2.5.22. A newer Bundler is being resolved at
runtime, so the pinned version is installed and then not used.

**Why it was open.** The pin was written deliberately, and only you know whether a project needed
2.3.26 specifically. Phase 3 rewrites that line either way, so this was the moment to decide what it
becomes.

**Product impact.** Nothing is broken today — 2.5.22 works. The risk is the pin reading as a
guarantee it does not provide. A future `bundle install` could resolve differently with nothing
flagging it.

**Options.**
(a) Drop the pin. Phase 3 installs `bundler` unpinned via `mise exec -- gem install bundler`. Cost:
Bundler follows the Ruby it runs under. Buys: the file stops claiming something untrue. Reversible.
(b) Make it real: pin it and assert it, `bundle --version | grep -q 2.3.26 || exit 1`. Cost: the
assertion breaks when a project's `Gemfile.lock` wants a different Bundler. Buys: a pin that holds.

**If you don't decide.** Phase 3 drops the pin, option (a), and says so in its diff.

**My call:** (a). A pin that does not bind is worse than no pin, and Bundler's own resolution from
`Gemfile.lock` is the mechanism that should win here. Reply `5a`.

### 1. Delete `run_dev_stack.sh`, or add `bin/dev` to the four projects that lack one and then delete it? → **1a**

**What this is.** `run_dev_stack.sh` (repo root, 379 lines) takes one project directory and starts
that project's Rails server plus an npm asset watcher, managing both PIDs itself. `bin/dev` is the
standard Rails equivalent: a two-line script that hands a `Procfile.dev` to `foreman`, which owns
the processes.

**Why it's open.** The script predates this plan and nothing in the repo calls it — a grep across
every `.md`, `.json` and `.sh` returns only its own two comment lines. Deleting a 379-line script
you wrote is a scope decision about your work, not housekeeping, which is why it is not in Phase 1.

**Product impact.** Eight projects already have both `bin/dev` and `Procfile.dev`, so for those the
script is redundant today. Four do not: `quick_wins`, `quick_wins_vAPI`, `secure_notes` and
`template`. `quick_wins` is the example in the script's own usage line. Delete the script with
nothing in its place and those four lose their one-command start. Three of the four have a
`package.json`; `quick_wins_vAPI` does not, so it needs a Rails-only `Procfile.dev`.

**Options.**
(a) Add `bin/dev` + `Procfile.dev` to the four, then delete the script. Cost: four two-line scripts,
four Procfiles, `foreman` in each Gemfile's development group. Buys: one start command across all
twelve projects, and process management that Rails maintains. Reversible. Touches the four project
directories and nothing in `.devcontainer/`.
(b) Delete the script, add nothing. Cost: those four projects start with two manual commands.
Buys: 379 lines gone now. Reversible via `git revert`.
(c) Keep and repair it. Cost: it needs the Phase 4 `localhost` → `db` change and `-b 0.0.0.0`, and
its `set -e` plus manual PID handling stay. Buys: no per-project files.

**If you don't decide.** The script stays as-is and acquires one edit in Phase 4. Nothing breaks.

**My call** (my opinion, yours to overturn): (a). The four projects that need it are exactly the
four without `bin/dev`, so the gap is small and closing it retires the whole script. Reply `1a`.

### 2. Can `projects_own/[DEPRECATED-DELETE]the_outperformer_os` be deleted? → **2a**, against my recommendation

**What this is.** A project directory whose name asks for its own deletion. It carries a
`.ruby-version` of 3.3.7, a `.ruby-gemset`, a `bin/dev` and a `Procfile.dev`.

**Why it's open.** Only you know whether anything in it is still wanted. Deleting a directory is
not undone by an edit, which is planning.md trigger 3.

**Product impact.** Keeping it costs one more `.ruby-gemset` to remove in Phase 3 and one more
bundle to reinstall. Nothing else in the plan touches it.

**Options.** (a) Delete it in Phase 1. Not reversible outside git history. (b) Leave it; Phase 3
migrates it with the others.

**If you don't decide.** It is migrated along with everything else. Small extra work, no risk.

**My call:** (b) — the saving is not worth an irreversible delete inside a migration. Reply `2b`.

### 3. Should the Phase 4 backup run on a schedule, and if so from where? → **3b**

**What this is.** After Phase 4 there is no automatic backup at all. Phase 1 removes the
start-time copy (defect D1) and Phase 4 replaces `pg-backup.sh`'s internals with a `pg_dump` you
run by hand. A scheduler such as `mcuadros/ofelia` is a small container added to `compose.yaml`
that runs a command in another service on a cron expression.

**Why it's open.** You asked for a maintainable bootstrap and for the iCloud writes to stop. You
never asked for scheduled backups. Adding a fourth container to the stack is a mechanism with no
sentence of yours behind it, so it is your call whether the plan grows one.

**Product impact.** With no schedule, a lost volume costs everything since your last manual dump.
With a schedule, a daily dump runs whether or not you remember. The dump must land off iCloud
either way, so a named volume or a path outside the repo.

**Options.**
(a) Manual only. Cost: you remember. Buys: no new container, no new image to keep current.
Reversible.
(b) Add an `ofelia` service to `compose.yaml`. Cost: one more container in every `up`, one more
third-party image, and its config lives in labels on the `db` service. Buys: a daily dump with no
action from you. Reversible — delete the service.
(c) A cron entry inside the app container. Cost: cron in a devcontainer only runs while the
container is up, and the app image has no cron daemon today.

**If you don't decide.** Phase 4 ships with manual dumps only, and the automatic backup you have
today is gone with nothing replacing it.

**My call:** (b), but scheduled for after Phase 4 is stable rather than inside it. The window where
you have no automatic backup is the risk, and a scheduler is the cheapest thing that closes it.
Reply `3b`.

### 4. Where should Phase 0 stop? → **4b**, against my recommendation

**What this is.** Phase 0 proposes a throwaway `.devcontainer-next` directory to test mise before
touching the working config. Eight items in this plan are unverified, listed in the phases
themselves.

**Why it's open.** A full parallel devcontainer is a second environment to build and maintain, and
it was added by a review pass, not by you. Most of what it would prove can be proved inside the
container you already have.

**Product impact.** A cheap Phase 0 answers the mise questions in minutes and risks nothing,
because installing mise into the running container changes no file under `.devcontainer/`. A full
`.devcontainer-next` answers the same questions plus the Compose networking one, and costs a
rebuild.

**Options.**
(a) Cheap: install mise into the running container by hand, check that a precompiled Ruby 3.2.0
arm64 binary exists, that it parses the `ruby-3.2.0` prefix form, and time the install. No new
files. Reversible by deleting `~/.local/share/mise`.
(b) Full `.devcontainer-next` as written. Also answers the `--network=host` question and the
`postgres:15` UID question before Phase 4. Costs a build and a second config to keep in step.

**If you don't decide.** Phase 0 runs as written, option (b).

**My call:** (a) for the mise questions now, and defer the networking and UID questions to the
start of Phase 4, where they belong. Reply `4a`.

### Decision sheet

| Reply | Meaning |
|---|---|
| `1a` | Add `bin/dev` to the four projects, then delete `run_dev_stack.sh` |
| `1b` | Delete `run_dev_stack.sh`, add nothing |
| `1c` | Keep and repair `run_dev_stack.sh` |
| `2a` | Delete the deprecated project in Phase 1 |
| `2b` | Keep it; migrate it with the rest |
| `3a` | Manual backups only |
| `3b` | Add the `ofelia` scheduler after Phase 4 is stable |
| `3c` | Cron inside the app container |
| `4a` | Cheap Phase 0 in the running container |
| `4b` | Full `.devcontainer-next` |

Answers given: `1a`, `2a`, `3b`, `4b`.

