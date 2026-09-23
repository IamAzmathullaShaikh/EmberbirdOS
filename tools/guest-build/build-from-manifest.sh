#!/usr/bin/env bash
# EmberbirdOS M2 X2 - build the Android-x86_64 guest from the pinned manifest.
#
# This is the ONE build recipe. It is runner-agnostic on purpose: the same script
# is what Crave executes remotely (see docs/M2-CRAVE-BUILD.md) and what
# .github/workflows/guest-build.yml executes on any runner that has the disk for it.
# Two copies of a build recipe drift; this file is the single source of truth.
#
# It does the provenance-critical work in the right order:
#   1. sync the pinned manifest, with the manifests checkout pinned to the exact
#      revision recorded in image/manifest/arcadia-x86.pin.json;
#   2. re-confirm the committed X1 lock against the synced tree using
#      `repo manifest -r` - the canonical build-side witness that the network-only
#      resolver (tools/manifest/resolve-manifest-lock.py) is checked against;
#   3. build the image;
#   4. emit image/out/x2-provenance.json (sha256 + size + toolchain + revision), which
#      is the X2 evidence record, plus a plain artifact list.
#
# Requirements: ~300 GB free, 16 GB+ RAM, git, python3, curl, and the repo launcher.
# On Crave none of that needs installing - that is the point of building there.
#
# Usage (local or CI):
#   bash tools/guest-build/build-from-manifest.sh
# Usage (Crave, from your machine, after the project is configured):
#   crave run --no-patch -- "bash tools/guest-build/build-from-manifest.sh"
#   crave pull image/out/          # fetch the image + X2 record back
#
# Env overrides: WORKSPACE, LUNCH_TARGET, MAKE_TARGET, MANIFEST_URL, MANIFEST_BRANCH,
#                MANIFEST_REVISION, JOBS, SYNC_JOBS, SKIP_SYNC (debug only).

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

MANIFEST_URL="${MANIFEST_URL:-https://github.com/BlissRoms-x86/manifest.git}"
MANIFEST_BRANCH="${MANIFEST_BRANCH:-arcadia-x86}"
LUNCH_TARGET="${LUNCH_TARGET:-bliss_x86_64-userdebug}"
MAKE_TARGET="${MAKE_TARGET:-iso_img}"
JOBS="${JOBS:-$(nproc 2>/dev/null || echo 8)}"
SYNC_JOBS="${SYNC_JOBS:-$JOBS}"
WORKSPACE="${WORKSPACE:-${HOME}/emberbird-build/aosp}"
OUT_DIR="$REPO_ROOT/image/out"
mkdir -p "$OUT_DIR"

log() { printf '\n\033[1;36m== %s\033[0m\n' "$*"; }
die() { printf '\n\033[1;31mFATAL: %s\033[0m\n' "$*" >&2; exit 1; }

# ---------------------------------------------------------------- preflight ---
log "preflight"
command -v git    >/dev/null || die "git is required"
command -v python3 >/dev/null || die "python3 is required"
avail_kb="$(df -Pk "$REPO_ROOT" | awk 'NR==2 {print $4}')"
avail_gb=$(( avail_kb / 1024 / 1024 ))
mem_gb=$(( $(awk '/MemTotal/ {print $2}' /proc/meminfo) / 1024 / 1024 ))
printf 'disk free: %s GB | RAM: %s GB | jobs: %s\n' "$avail_gb" "$mem_gb" "$JOBS"
if [ "$avail_gb" -lt 250 ]; then
  die "only ${avail_gb} GB free; a repo sync + build needs ~300 GB. Use Crave (docs/M2-CRAVE-BUILD.md) or a runner with the disk."
fi
if [ "$mem_gb" -lt 15 ]; then
  die "only ${mem_gb} GB RAM; the AOSP build expects 16 GB+."
fi

# Resolve the revision to build from the committed pin, so this script never
# builds something other than what X1 locked.
MANIFEST_REVISION="${MANIFEST_REVISION:-$(python3 -c "import json;print(json.load(open('image/manifest/arcadia-x86.pin.json'))['manifest']['revision'])")}"
printf 'manifest: %s @ %s (%s)\n' "$MANIFEST_URL" "$MANIFEST_REVISION" "$MANIFEST_BRANCH"

if [ -z "${SKIP_SYNC:-}" ]; then
  log "installing the repo launcher"
  mkdir -p "$HOME/bin"
  if [ ! -x "$HOME/bin/repo" ]; then
    curl -fsSL https://storage.googleapis.com/git-repo-downloads/repo -o "$HOME/bin/repo"
    chmod a+x "$HOME/bin/repo"
  fi
  export PATH="$HOME/bin:$PATH"
  repo --version

  log "repo init + pin manifests to the X1 revision"
  mkdir -p "$WORKSPACE"
  cd "$WORKSPACE"
  # --git-lfs matches the recorded M1 build recipe; -c keeps it to the current branch.
  repo init -u "$MANIFEST_URL" -b "$MANIFEST_BRANCH" --git-lfs
  git -C .repo/manifests fetch --depth=1 origin "$MANIFEST_REVISION"
  git -C .repo/manifests checkout --detach "$MANIFEST_REVISION"
  pinned_manifests="$(git -C .repo/manifests rev-parse HEAD)"
  printf 'manifests checkout: %s\n' "$pinned_manifests"
  [ "$pinned_manifests" = "$MANIFEST_REVISION" ] \
    || die "manifests checkout is $pinned_manifests, expected $MANIFEST_REVISION"

  log "repo sync (this is the multi-hour, multi-hundred-GB step)"
  repo sync -c -j"$SYNC_JOBS" --no-tags --force-sync

  log "canonical check: repo manifest -r against the committed X1 lock"
  repo manifest -r -o "$OUT_DIR/repo-manifest-r.xml"
  cd "$REPO_ROOT"
  python3 tools/manifest/verify-lock.py || die "the synced tree does not match the committed X1 lock - stopping before the build"
else
  log "SKIP_SYNC set - reusing the existing workspace (debug only)"
  cd "$WORKSPACE"
fi

# ------------------------------------------------------------------- build ---
log "build: lunch $LUNCH_TARGET && make $MAKE_TARGET"
cd "$WORKSPACE"
# shellcheck disable=SC1091
source build/envsetup.sh
lunch "$LUNCH_TARGET"
make -j"$JOBS" "$MAKE_TARGET"

log "SBOM (best effort - not every tree supports it)"
if ! ( source build/envsetup.sh && lunch "$LUNCH_TARGET" && m sbom ) >/dev/null 2>&1; then
  echo "note: 'm sbom' unavailable in this tree; SBOM will be generated at release time (M1 section 7)"
fi

# --------------------------------------------------------------- evidence ----
log "X2 provenance record"
cd "$REPO_ROOT"
MANIFEST_REVISION="$MANIFEST_REVISION" LUNCH_TARGET="$LUNCH_TARGET" MAKE_TARGET="$MAKE_TARGET" \
PYTHONPATH="$REPO_ROOT" python3 - "$WORKSPACE" "$OUT_DIR" <<'PY'
import datetime, hashlib, json, os, pathlib, platform, sys

ws, out_dir = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
imgs = sorted(p for p in list(ws.glob('out/**/*.iso')) + list(ws.glob('out/**/*.img')) if p.is_file())
records = []
for p in imgs:
    h = hashlib.sha256()
    with p.open('rb') as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b''):
            h.update(chunk)
    records.append({'artifact': p.name, 'sha256': h.hexdigest(), 'bytes': p.stat().st_size})
    print('  %s  %s  %d bytes' % (h.hexdigest(), p.name, p.stat().st_size))

rec = {
    'criterion': 'M2 X2 - guest artifact provenance',
    'kind': 'built-from-pinned-manifest',
    'manifest_url': 'https://github.com/BlissRoms-x86/manifest.git',
    'manifest_revision': os.environ.get('MANIFEST_REVISION', ''),
    'lunch': os.environ.get('LUNCH_TARGET', ''),
    'make_target': os.environ.get('MAKE_TARGET', ''),
    'build_host': platform.platform(),
    'build_utc': datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'),
    'provenance_anchor': 'image/manifest/arcadia-x86.pinned.xml (X1 per-project lock)',
    'lock_confirmed_by': 'repo manifest -r, checked with tools/manifest/verify-lock.py',
    'artifacts': records,
}
(out_dir / 'x2-provenance.json').write_text(json.dumps(rec, indent=2) + '\n')
(out_dir / 'artifacts.txt').write_text('\n'.join(r['artifact'] for r in records) + '\n')
print(json.dumps(rec, indent=2))
if not records:
    print('note: no .iso/.img found under out/ - check MAKE_TARGET')
PY

log "done - pull these back"
echo "  $OUT_DIR/x2-provenance.json"
echo "  $OUT_DIR/artifacts.txt"
echo "  the image itself"
echo
echo "On Crave:  crave pull image/out/"
echo "Then verify the sha256 above, and run M2 X3-X5 with the frozen launcher:"
echo "  .\\tools\\qemu\\provision-host.ps1 -Check"
echo "  .\\tools\\qemu\\launch-emberbird.ps1 -Image <path> -DryRun"
echo "  .\\tools\\qemu\\launch-emberbird.ps1 -Image <path>"
