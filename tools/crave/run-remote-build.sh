#!/usr/bin/env bash
# EmberbirdOS - launch the M2 X2 guest build on Crave, then pull the results back.
#
# WHY THERE IS A SCRIPT FOR THIS
#   Crave resolves the project *from the git URL of the current directory*. This
#   repository's URL is not a Crave project, so running `crave run` from a plain checkout
#   fails with:
#
#     Error: could not get project information for <this repo>
#
#   (A project is not needed and is deliberately not created: M2's provenance anchor is
#   the X1 lock, not a Crave project. The base project is only a container.)
#
#   So the job is launched from a throwaway checkout - a "ticket" - whose origin IS the
#   base project's source URL, and the job bootstraps this repository inside the remote
#   workspace at the exact commit you are standing on. That keeps the build reproducible
#   from any machine with the client and an API key.
#
# USAGE
#   bash tools/crave/run-remote-build.sh run      # launch (default), detached
#   bash tools/crave/run-remote-build.sh status   # queue state + tail of the log
#   bash tools/crave/run-remote-build.sh log      # full remote log
#   bash tools/crave/run-remote-build.sh pull     # fetch image/out/* back into this repo
#   bash tools/crave/run-remote-build.sh stop     # stop the job on this workspace
#
# TUNABLES (env)
#   CRAVE_PROJECT_ID     default 36 (LOS 20 - Crave's Android 13 AOSP base)
#   CRAVE_PROJECT_NAME   default "LOS 20"
#   CRAVE_PROJECT_URL    default https://github.com/accupara/los20.git
#   CRAVE_PLATFORM       default linux16  (the only capable platform project 36 accepts;
#                                          see docs/M2-CRAVE-BUILD.md for the probe matrix)
#   COMMIT               default: current HEAD of this checkout (pinned into the job)
#   TICKET_DIR           default $TEMP/crave-ticket-<project id>
#   ATTACH=1             stream the build in the foreground instead of detaching
#
# Everything goes through tools/crave/crave.sh, so the client's broken self-update path
# (docs/CRAVE-CLIENT-UPDATE-LOOP.md) is never entered.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CRAVE_SHIM="$REPO_ROOT/tools/crave/crave.sh"

CRAVE_PROJECT_ID="${CRAVE_PROJECT_ID:-36}"
CRAVE_PROJECT_NAME="${CRAVE_PROJECT_NAME:-LOS 20}"
CRAVE_PROJECT_URL="${CRAVE_PROJECT_URL:-https://github.com/accupara/los20.git}"
CRAVE_PLATFORM="${CRAVE_PLATFORM:-linux16}"
TICKET_DIR="${TICKET_DIR:-${TEMP:-${TMPDIR:-/tmp}}/crave-ticket-${CRAVE_PROJECT_ID}}"

log() { printf '\n\033[1;36m== %s\033[0m\n' "$*"; }
die() { printf '\033[1;31mFATAL: %s\033[0m\n' "$*" >&2; exit 1; }

[ -f "$CRAVE_SHIM" ] || die "missing $CRAVE_SHIM"

repo_url="$(git -C "$REPO_ROOT" remote get-url origin)"
branch="$(git -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD)"
COMMIT="${COMMIT:-$(git -C "$REPO_ROOT" rev-parse HEAD)}"
# A window into a private repo would fail remotely; fail loudly here instead.
git -C "$REPO_ROOT" ls-remote --exit-code origin "refs/heads/$branch" >/dev/null 2>&1 \
  || die "origin/$branch is not reachable - push before launching a build from it"

# ------------------------------------------------------------------ the ticket ----
# A checkout whose origin is the base project's URL: that is what makes `crave run`
# resolve project $CRAVE_PROJECT_ID. Deliberately outside this repository, so the client
# cannot walk up into it and resolve *our* (unregistered) remote instead.
ensure_ticket() {
  if [ -d "$TICKET_DIR/.git" ]; then
    log "refreshing the ticket checkout ($TICKET_DIR)"
    git -C "$TICKET_DIR" fetch --depth=1 -q origin "refs/heads/$(git -C "$TICKET_DIR" rev-parse --abbrev-ref HEAD)" 2>/dev/null || true
    git -C "$TICKET_DIR" pull --ff-only -q 2>/dev/null || true
  else
    log "creating the ticket checkout ($TICKET_DIR)"
    rm -rf "$TICKET_DIR"
    git clone --depth=1 -q "$CRAVE_PROJECT_URL" "$TICKET_DIR"
  fi
  # crave.yaml must live at the top of the tree the client runs in for its project
  # overrides (ignoreClientHostname, no-patch) to apply to this job.
  cp -f "$REPO_ROOT/crave.yaml" "$TICKET_DIR/crave.yaml" 2>/dev/null || true
  printf 'ticket origin: %s\n' "$(git -C "$TICKET_DIR" remote get-url origin)"
}

# --------------------------------------------------------- the remote command ----
# Checkout this exact commit, then hand over to the one build recipe.
remote_cmd() {
  cat <<EOF
bash -lc '
set -x
echo "--- host probe (recorded for the X2 record) ---"
nproc; free -g | head -3; df -h .; df -h \$HOME
command -v git python3 curl
echo "--- bootstrap EmberbirdOS @ $COMMIT ---"
rm -rf eb
git init -q eb && cd eb
git remote add origin $repo_url
if ! git fetch --depth=1 -q origin $COMMIT; then
  echo "note: fetch-by-sha refused by the remote; falling back to the branch tip"
  git fetch --depth=1 -q origin refs/heads/$branch
fi
git checkout -q FETCH_HEAD
echo "building commit: \$(git rev-parse HEAD)  branch: $branch"
WORKSPACE="\$(pwd)/emberbird-aosp" bash tools/guest-build/build-from-manifest.sh
'
EOF
}

cmd="${1:-run}"
case "$cmd" in
  run)
    ensure_ticket
    log "launching: project $CRAVE_PROJECT_NAME (id $CRAVE_PROJECT_ID), platform $CRAVE_PLATFORM"
    printf 'recipe commit: %s (%s)\n' "$COMMIT" "$branch"
    if [ -n "${ATTACH:-}" ]; then
      cd "$TICKET_DIR"
      exec bash "$CRAVE_SHIM" run --projectID "$CRAVE_PROJECT_ID" --platform "$CRAVE_PLATFORM" \
        --no-patch --no-artifacts \
        --message "M2 X2: EmberbirdOS guest from pinned X1 lock @ $COMMIT" \
        -- "$(remote_cmd)"
    else
      mkdir -p "$REPO_ROOT/image/out"
      ( cd "$TICKET_DIR" && bash "$CRAVE_SHIM" run --projectID "$CRAVE_PROJECT_ID" \
          --platform "$CRAVE_PLATFORM" --detached --json --no-patch --no-artifacts \
          --message "M2 X2: EmberbirdOS guest from pinned X1 lock @ $COMMIT" \
          -- "$(remote_cmd)" ) | tee "$REPO_ROOT/image/out/crave-job.txt"
      echo
      echo "watch:  bash tools/crave/run-remote-build.sh status"
      echo "log:    bash tools/crave/run-remote-build.sh log"
      echo "pull:   bash tools/crave/run-remote-build.sh pull"
    fi
    ;;

  status)
    ensure_ticket >/dev/null
    ( cd "$TICKET_DIR" && bash "$CRAVE_SHIM" list | sed -n '/Your jobs/,$p' | head -8
      bash "$CRAVE_SHIM" getlog 2>&1 | tail -25 )
    ;;

  log)
    ensure_ticket >/dev/null
    ( cd "$TICKET_DIR" && bash "$CRAVE_SHIM" getlog )
    ;;

  pull)
    ensure_ticket >/dev/null
    log "pulling eb/image/out/ from the remote workspace into $REPO_ROOT/image/out"
    ( cd "$TICKET_DIR" && bash "$CRAVE_SHIM" pull eb/image/out/ )
    src="$TICKET_DIR/eb/image/out"
    if [ -d "$src" ]; then
      mkdir -p "$REPO_ROOT/image/out"
      cp -f "$src"/* "$REPO_ROOT/image/out/" 2>/dev/null || true
      ls -l "$REPO_ROOT/image/out"
      echo
      echo "X2 record: $REPO_ROOT/image/out/x2-provenance.json"
      echo "Commit it as docs/evidence/M2/x2-artifact-provenance.json once you have"
      echo "re-hashed the image locally and filled in the M2 appendix row."
    else
      die "remote pull produced no $src - has the build finished? (bash tools/crave/run-remote-build.sh status)"
    fi
    ;;

  stop)
    ensure_ticket >/dev/null
    ( cd "$TICKET_DIR" && bash "$CRAVE_SHIM" stop --force )
    ;;

  *) die "unknown command '$cmd' (run|status|log|pull|stop)" ;;
esac
