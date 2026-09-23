# M2 X2 — building the guest on Crave (remote), then pulling it locally

> **Why this exists.** M2's X2 artifact (the Android-x86_64 guest image) must be built
> from the pinned manifest, and a from-source build of BlissOS `arcadia-x86` needs
> ~300 GB of disk. The M2 host has ~104 GB, and there is no provenance-usable prebuilt
> to fall back on ([`evidence/M2/x2-artifact-availability.txt`](evidence/M2/x2-artifact-availability.txt)):
> BlissOS's public images are paused. So the build runs **remotely** — on [Crave](https://foss.crave.io),
> the platform the Android ROM community uses for exactly this — and only the small
> results come back: the image plus its X2 provenance record.
>
> **This is a runbook, not a result.** Nothing in M2 has been built yet. The recipe and
> the instructions below are committed; the run itself needs your Crave account.

## What runs where

| Step | Where | Artifact |
|---|---|---|
| `repo init` + pin manifests to the X1 revision | Crave machine | pinned checkout |
| `repo sync -c` (~300 GB, the expensive part) | Crave machine | synced tree |
| `repo manifest -r`, checked against the committed X1 lock | Crave machine | [`image/out/repo-manifest-r.xml`](../image/out) (git-ignored) |
| `lunch` + `make iso_img` | Crave machine | the guest image |
| SHA-256 + size + revision + toolchain → X2 record | Crave machine | `image/out/x2-provenance.json` |
| `crave pull image/out/` | your machine | the image + the X2 record |
| Boot it with the frozen launcher (X3–X5) | your Windows host | [`evidence/M2/`](evidence/M2/) |

One recipe drives all of it: [`../tools/guest-build/build-from-manifest.sh`](../tools/guest-build/build-from-manifest.sh).
The same script is what [`.github/workflows/guest-build.yml`](../.github/workflows/guest-build.yml)
runs on any runner with the disk, so the Crave path and the CI path cannot drift.

## One-time setup

1. **Crave account + client.** Sign in at <https://foss.crave.io>, then from the
   *Downloads* tab take the client for your platform, and from *API Keys* take your
   `crave.conf`.
2. **Keep the credential out of the repo.** `crave.conf` is an API key. Crave looks for
   it in the working directory or any parent, then in `$HOME`, or you can point at it
   with `-c`. Store it as `~/crave.conf` — **never** commit it (`.gitignore` does not
   need to cover it if it lives in `$HOME`; do not copy it into the tree).
3. **Configure the project once, in the Crave UI.** Crave maps a project to a source
   URL; create one whose source URL is this repository's GitHub URL, and grant yourself
   access. That is what lets `crave run` clone *this* repo onto the build machine.
        - Until the push in this milestone lands, that URL does not exist yet — the
          project cannot be created before the repo is on GitHub. Do this after.

## The build

From a checkout of this repository:

```sh
# remote build: sync at the pinned revision, verify the X1 lock, build, hash
crave run --no-patch -- "bash tools/guest-build/build-from-manifest.sh"

# pull back only the small results
crave pull image/out/
```

`--no-patch` builds the committed revision as-is instead of uploading your local
diff — which is what we want, because X2 must describe **the pinned manifest**, not a
working tree. The first run pays for the full `repo sync`; Crave caches build trees and
compiler output, so later runs are much cheaper.

Prefer a persistent environment? Enter a devspace and run the same script inside it:

```sh
crave -c ~/crave.conf devspace
# inside the devspace:
crave clone create --projectID <your project id> emberbird && cd emberbird
crave run --no-patch -- "bash tools/guest-build/build-from-manifest.sh"
```

Overridable environment variables (set them inside the `crave run` command string):

| Var | Default |
|---|---|
| `LUNCH_TARGET` | `bliss_x86_64-userdebug` |
| `MAKE_TARGET` | `iso_img` |
| `MANIFEST_URL` / `MANIFEST_BRANCH` | `https://github.com/BlissRoms-x86/manifest.git` / `arcadia-x86` |
| `MANIFEST_REVISION` | read from [`image/manifest/arcadia-x86.pin.json`](../image/manifest/arcadia-x86.pin.json) |
| `WORKSPACE` | `$HOME/emberbird-build/aosp` |
| `JOBS` / `SYNC_JOBS` | `nproc` |

## What you should see, and what to check before trusting it

The script refuses to build if the runner lacks the disk or RAM, and — importantly —
**refuses to build if the synced tree does not match the committed X1 lock**, because a
build from an unlocked tree would be an X2 claim we could not substantiate. So a
successful run is itself evidence that the lock and the tree agree.

On pull-back:

1. Check `image/out/x2-provenance.json` exists and lists at least one artifact with a
   `sha256` and `bytes` — that record *is* X2.
2. Re-hash the downloaded image locally and confirm it matches:
   ```powershell
   Get-FileHash .\bliss_arcadia-x86.iso -Algorithm SHA256
   ```
3. Commit the record as `docs/evidence/M2/x2-artifact-provenance.json` and fill in the
   X2 row of the [execution appendix](M2-GUEST-BOOT-PROOF.md#8-execution-appendix-2026-09-24)
   with the observed values. Until that happens, **X2 stays OPEN** — the artifact is not
   the evidence; the recorded hash and provenance is.
4. Then execute X3–X5 on the Windows host:
   ```powershell
   .\tools\qemu\provision-host.ps1 -Check
   .\tools\qemu\launch-emberbird.ps1 -Image <path> -DryRun   # X3: resolved argv
   .\tools\qemu\launch-emberbird.ps1 -Image <path>           # X4: usable UI
   adb connect 127.0.0.1:58526                               # X5: liveness
   ```

## Honest limitations

- **Not executed here.** A Crave run needs your account, an API key and a configured
  project; this repo therefore commits the recipe, the runbook and the verification
  steps, and records X2 as OPEN rather than pretending otherwise.
- **Crave is a third-party service.** It sees the source it builds. Nothing secret lives
  in this repo; the proprietary ARM translators and GApps are explicitly never committed
  (see [../docs/LICENSING.md](LICENSING.md)), so there is nothing in the tree that
  should not be on a build host.
- **The frozen launcher is untouched** by this path. If a launcher change turns out to
  be needed to boot what we build, that is an M0-reopen decision for the owner, not an
  inline edit — record it as a finding and stop (M2 §4.3).
- **`repo sync` is the canonical provenance step**, and it now runs in both places: here
  on Crave, and in `guest-build.yml` on a big-disk runner. Both compare the synced tree
  against `image/manifest/arcadia-x86.pinned.xml` with `tools/manifest/verify-lock.py`.

## Related

- M2 execution spec + appendix: [`M2-GUEST-BOOT-PROOF.md`](M2-GUEST-BOOT-PROOF.md)
- X1 lock and its reproducibility proof: [`../image/manifest/README.md`](../image/manifest/README.md),
  [`evidence/M2/x1-lock-reproducibility.txt`](evidence/M2/x1-lock-reproducibility.txt)
- Why no prebuilt: [`evidence/M2/x2-artifact-availability.txt`](evidence/M2/x2-artifact-availability.txt)
- Alternative runner: [`.github/workflows/guest-build.yml`](../.github/workflows/guest-build.yml)
