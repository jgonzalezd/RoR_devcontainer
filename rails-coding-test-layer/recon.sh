#!/usr/bin/env bash
# Read-only recon for the fast-track grill. One call, capped output.
#
#   rails-coding-test-layer/recon.sh [project_dir]     (default: current directory)
#
# Prints: STACK verdict with file:line evidence, auth, schema, routes, models, rules in force, controllers,
# tests and test prior art, git branch, workflow files. The stack is judged by what the code USES
# (JS mounts, render calls, view helpers), never by which gems are installed: a default
# Rails 8 app ships turbo-rails even when every page is a Vue or React island.
set -uo pipefail

dir="${1:-.}"
cd "$dir" 2>/dev/null || { echo "recon: no such directory: $dir" >&2; exit 1; }
[ -f Gemfile ] || { echo "recon: $PWD has no Gemfile (not a Rails project?)" >&2; exit 1; }

CAP=12
section() { printf '\n## %s\n' "$1"; }
cap() { head -n "${1:-$CAP}"; }
# first match as path:line, or empty
first() { grep -rnE -m1 "$@" 2>/dev/null | head -n1 | cut -d: -f1,2; }
count() { grep -rlE "$@" 2>/dev/null | wc -l | tr -d ' '; }

JS_DIRS=$(ls -d app/javascript app/frontend 2>/dev/null | tr '\n' ' ')
VIEW_DIR=app/views

echo "# recon: $(basename "$PWD")"
rails_v=$(grep -m1 -E '^    rails \(' Gemfile.lock 2>/dev/null | sed -E 's/.*\((.*)\)/\1/')
tests=$( [ -d spec ] && echo RSpec || echo Minitest )
lint=$( [ -x bin/rubocop ] && echo rubocop || echo none )
echo "Rails ${rails_v:-?} · tests: $tests · lint: $lint"
# Agent shells (Pi's bash tool) are often non-login: no rvm, so no ruby, and every ralph script fails.
if command -v ruby >/dev/null 2>&1; then
  echo "Shell: ruby on PATH ($(ruby -e 'print RUBY_VERSION' 2>/dev/null))"
elif [ -s "$HOME/.rvm/scripts/rvm" ]; then
  rv=$(sed -nE 's/.*rvm use ([^ ]+).*/\1/p' .rvmrc 2>/dev/null | head -n1)
  rv=${rv:-$(cat .ruby-version 2>/dev/null)}
  echo "Shell: ruby is NOT on PATH here. Prefix every command with: . ~/.rvm/scripts/rvm && rvm use ${rv:-default} >/dev/null && "
else
  echo "Shell: ruby is NOT on PATH and no rvm found: ask the human for the ruby path"
fi

# ---------------------------------------------------------------- stack
section "Stack (verdict from usage, with evidence)"
ev=()
fw=""
for f in vue react svelte; do
  grep -qE "\"$f\"\s*:" package.json 2>/dev/null && fw="${fw:+$fw+}$f"
done

inertia_render=$(first 'render inertia:|inertia:' app/controllers)
inertia_boot=$( [ -n "$JS_DIRS" ] && first 'createInertiaApp' $JS_DIRS )
mount=$( [ -n "$JS_DIRS" ] && first --include='*.js' --include='*.ts' --include='*.jsx' --include='*.tsx' \
  -e 'createApp\(' -e 'createRoot\(' -e 'ReactDOM\.render' -e 'new Vue\(' -e '\.mount\(' $JS_DIRS )

# View shells: non-layout ERB files that hold a mount point and no server-side form/link helpers.
shells=(); server_views=()
while IFS= read -r v; do
  if grep -qE 'form_with|form_for|form_tag|link_to|button_to|render |turbo_frame_tag|turbo_stream' "$v"; then
    server_views+=("$v")
  elif grep -qE '<div id="[^"]+"' "$v"; then
    shells+=("$v:$(grep -nE -m1 '<div id="[^"]+"' "$v" | cut -d: -f1)")
  fi
done < <(find "$VIEW_DIR" -name '*.erb' -not -path '*/layouts/*' -not -path '*/pwa/*' 2>/dev/null | sort)

turbo_use=$(first -e 'turbo_frame_tag' -e 'turbo_stream' -e 'data-turbo-frame' "$VIEW_DIR" app/components)
stim_use=$( [ -n "$JS_DIRS" ] && first --include='*_controller.js' --exclude='hello_controller.js' 'extends Controller' $JS_DIRS )  # hello_controller.js is the Rails scaffold
vc=$(ls app/components/*_component.rb 2>/dev/null | head -n1)
json_ctrl=$(count 'render json:' app/controllers)
html_ctrl=$(grep -rLE 'render json:' app/controllers 2>/dev/null | xargs -r grep -lE 'def (index|show|new|edit)' 2>/dev/null | grep -v application_controller | wc -l | tr -d ' ')
api_base=$(first -e 'ActionController::API' app/controllers)

[ -n "$fw" ] && ev+=("package.json declares: $fw")
[ -n "$mount" ] && ev+=("JS mount: $mount")
[ -n "$inertia_boot" ] && ev+=("Inertia boot: $inertia_boot")
[ -n "$inertia_render" ] && ev+=("Inertia render: $inertia_render")
for s in "${shells[@]:0:4}"; do ev+=("mount-point view shell: $s"); done
[ "${#server_views[@]}" -gt 0 ] && ev+=("server-rendered views: ${#server_views[@]} (e.g. ${server_views[0]})")
[ -n "$turbo_use" ] && ev+=("Turbo used in views: $turbo_use")
[ -n "$stim_use" ] && ev+=("Stimulus controller: $stim_use")
[ -n "$vc" ] && ev+=("ViewComponent: $vc")
ev+=("controllers rendering JSON: $json_ctrl · HTML page controllers: $html_ctrl")
[ -n "$api_base" ] && ev+=("API-only base controller: $api_base")

if [ -n "$inertia_render" ] || [ -n "$inertia_boot" ]; then
  verdict="Inertia (${fw:-js}) pages: controllers render inertia props; UI lives in JS page components"
  impl="New UI = a ${fw:-JS} page component + a controller action rendering inertia props. ERB/Turbo pages would be a stack change."
elif [ -n "$mount" ] && [ "${#shells[@]}" -ge "${#server_views[@]}" ]; then
  verdict="SPA islands: ${fw:-JS} components mounted into ERB shells; data over the JSON API"
  impl="New UI = a ${fw:-JS} component calling a JSON endpoint. Server-rendered ERB/Turbo UI would be a stack change (HITL prefactor or Out of Scope)."
elif [ -n "$mount" ]; then
  verdict="Mixed: server-rendered pages plus ${fw:-JS} islands"
  impl="Ask which side the new UI belongs to; follow the page the feature extends."
elif [ "${#server_views[@]}" -gt 0 ] || [ -n "$turbo_use" ] || [ -n "$stim_use" ] || [ -n "$vc" ]; then
  verdict="Server-rendered Rails (ERB${vc:+ + ViewComponent}${turbo_use:+ + Turbo}${stim_use:+ + Stimulus})"
  impl="New UI = ERB views${vc:+/components} with Turbo/Stimulus where needed; no JSON API unless asked."
elif [ "$json_ctrl" -gt 0 ] && [ "$html_ctrl" -eq 0 ]; then
  verdict="JSON API only (no UI in this app)"
  impl="Features are endpoints + request tests; any UI is out of this app."
else
  hot=$(grep -oE '^\s*gem "(turbo-rails|stimulus-rails)"' Gemfile 2>/dev/null | grep -oE '(turbo|stimulus)-rails' | paste -sd' ' -)
  verdict="Server-rendered Rails, no feature views yet (default Hotwire: ${hot:-none installed})"
  impl="New UI = ERB views with Turbo/Stimulus (Rails default); first feature sets the pattern."
fi
echo "VERDICT: $verdict"
echo "IMPLICATION: $impl"
printf 'evidence:\n'; printf '  - %s\n' "${ev[@]}"

# ---------------------------------------------------------------- auth
section "Auth"
auth=$( { grep -nE '^\s*gem "(devise|rodauth-rails|sorcery|clearance)"' Gemfile
          grep -rnE 'has_secure_password|def current_user|def authenticate|Current\.(user|session)|session\[:user_id\]\s*=' app/models app/controllers 2>/dev/null; } | cap 6 )
echo "${auth:-no auth found}"

# ---------------------------------------------------------------- schema
section "Schema (db/schema.rb)"
if [ -f db/schema.rb ]; then
  awk '/create_table/ {match($0,/"[^"]+"/); t=substr($0,RSTART+1,RLENGTH-2); cols=""; idx=""}
       /^\s+t\.index/ && t { match($0,/\[[^]]+\]/); k=substr($0,RSTART,RLENGTH); gsub(/"/,"",k); if ($0 ~ /unique: true/) { idx=idx " unique" k; u++ }; next }
       /^\s+t\./ && t { match($0,/"[^"]+"/); c=substr($0,RSTART+1,RLENGTH-2); split($1,a,"."); cols=cols (cols?", ":"") c ":" a[2] ($0 ~ /null: false/ ? "!" : "") }
       /^\s+end$/ && t { print "- " t "(" cols ")" idx; t="" }
       /^\s*add_foreign_key/ { fk++ }
       END { print "(! = null: false; unique indexes: " u+0 "; foreign keys: " fk+0 ")" }' db/schema.rb | cap 20
else echo "no db/schema.rb"; fi

# ---------------------------------------------------------------- routes
section "Routes (config/routes.rb, comments dropped)"
grep -vE '^\s*(#|$)' config/routes.rb | cap 25

# ---------------------------------------------------------------- models / controllers
section "Models (associations, validations, scopes)"
for m in app/models/*.rb; do
  [ "$(basename "$m")" = application_record.rb ] && continue
  lines=$(grep -nE '^\s*(belongs_to|has_many|has_one|has_and_belongs|validates?|scope|has_secure_password)' "$m" | sed -E 's/^([0-9]+):\s*/\1: /' | cap 6 | paste -sd';' -)
  echo "- $m${lines:+: $lines}"
done | cap 15

# Business rules (ADR-0010): the register first; the validations above and the schema's
# constraints are the rules in code. The next ID continues after RULES.md, the PRD and tickets.
section "Rules in force (RULES.md)"
if [ -f RULES.md ]; then
  grep -E '^(## |- \*\*BR-[0-9]{3}\.\*\*)' RULES.md | cap 15
else
  echo "none registered (the validations above and the schema's constraints are the rules in code)"
fi
hi=$(cat RULES.md issues/*.md issues/done/*.md 2>/dev/null | grep -oE 'BR-[0-9]{3}' | sort -u | tail -n1 | sed 's/BR-//')
printf 'next rule ID: BR-%03d\n' $(( 10#${hi:-0} + 1 ))

section "Controllers (actions; render mode)"
find app/controllers -name '*.rb' -not -name application_controller.rb | sort | while read -r c; do
  acts=$(grep -oE '^\s*def [a-z_]+' "$c" | awk '{print $2}' | paste -sd, -)
  mode=$(grep -qE 'render json:' "$c" && echo json || echo html)
  echo "- $c [$mode]: $acts"
done | cap 15

# ---------------------------------------------------------------- tests
section "Tests"
tdir=$( [ -d spec ] && echo spec || echo test )
find "$tdir" -name '*_test.rb' -o -name '*_spec.rb' 2>/dev/null | grep -v '/fixtures/' | sort | cap 15
echo "prior-art helpers (login, factories):"
{ grep -rnE 'def (log_?in|sign_?in|login_as|authenticate)[a-z_]*' "$tdir" 2>/dev/null
  grep -rnE -m1 '^\s*(post|get) .*(log_?in|sign_?in|session)' "$tdir" 2>/dev/null; } | cap 5 | sed 's/^/  /'
fx=$(ls "$tdir"/fixtures/*.yml 2>/dev/null | paste -sd' ' -); [ -n "$fx" ] && echo "  fixtures: $fx"

# ---------------------------------------------------------------- git
section "Git"
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  br=$(git branch --show-current 2>/dev/null); br=${br:-"(detached)"}
  def=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||')
  [ -z "$def" ] && for b in main master; do git rev-parse -q --verify "refs/heads/$b" >/dev/null && { def=$b; break; }; done
  dirty=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
  if [ -n "$def" ] && [ "$br" != "$def" ]; then
    ahead=$(git rev-list --count "$def..HEAD" 2>/dev/null || echo "?")
    echo "branch: $br · default: $def · $ahead commit(s) ahead · $dirty dirty file(s)"
    git log --format='  %h %s' "$def..HEAD" 2>/dev/null | cap 5
  else
    echo "branch: $br · default: ${def:-none found} · $dirty dirty file(s)"
  fi
else
  echo "not a git repo"
fi

# ---------------------------------------------------------------- workflow
section "Workflow files"
for f in AGENTS.md .pi/project-profile.md ralph/once.sh ralph/preflight issues/; do
  [ -e "$f" ] && echo "- $f: present" || echo "- $f: MISSING"
done
[ -x ralph/preflight ] && echo "Run ralph/preflight --plan before the tickets are approved."
exit 0
