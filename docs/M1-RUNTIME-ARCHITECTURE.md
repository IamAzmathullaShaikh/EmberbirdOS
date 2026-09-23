# EmberbirdOS — M1: Runtime Source & Build Architecture

> **Milestone gate deliverable.** Establishes the guest-image, source-provenance, kernel, graphics, native-bridge, GMS, and reproducible-build architecture **before** any Native Android Runtime code is written.
>
> **Status:** M1 architecture authored `2026-09-23`; independent architectural review returned **PASS** (`2026-09-23`); **ACCEPTED BY THE OWNER `2026-09-24` — the gate is signed off and M2 (Guest Boot Proof) is unblocked and in execution.** **M0 (launcher + adversarial corrections A–G + durable regression suite) is ACCEPTED and frozen.** This document is *planning/architecture only* — no `host/` or `guest/` runtime code is authored under M1, and owning this gate does not authorize any.
>
> **Governance rule (binding):** *No production Native Android Runtime implementation begins merely because the launcher is green. M1 must first establish the guest-image, source provenance, kernel, graphics, compatibility, and licensing architecture.*
>
> **Extends:** [`PLAN.md`](../PLAN.md) §6.2 / §6.3 / §6.5 / §10 / §12 · [`docs/RESEARCH-SYNTHESIS.md`](RESEARCH-SYNTHESIS.md) · [`docs/LICENSING.md`](LICENSING.md)
> **Evidence base:** four 2026-current research passes — guest-base lineage, ARM/native-bridge, graphics-on-Windows, GMS/provenance/reproducible-build. Confidence tags **[H]/[M]/[L]** per [`RESEARCH-SYNTHESIS.md`](RESEARCH-SYNTHESIS.md).

---

## Table of contents

0. [Purpose, scope & the milestone gate spine](#0-purpose-scope--the-milestone-gate-spine)
1. [Decision ledger (authoritative status board)](#1-decision-ledger-authoritative-status-board)
2. [Sub-decision 1 — Guest base & source lineage](#2-sub-decision-1--guest-base--source-lineage)
3. [Sub-decision 2 — Kernel strategy](#3-sub-decision-2--kernel-strategy)
4. [Sub-decision 3 — Graphics stack (the plan-changing finding)](#4-sub-decision-3--graphics-stack-the-plan-changing-finding)
5. [Sub-decision 4 — Native-bridge boundary (ARM = optional layer)](#5-sub-decision-4--native-bridge-boundary-arm--optional-layer)
6. [Sub-decision 5 — GMS boundary](#6-sub-decision-5--gms-boundary)
7. [Sub-decision 6 — Provenance & attestation](#7-sub-decision-6--provenance--attestation)
8. [Sub-decision 7 — Reproducible-build & signing/OTA model](#8-sub-decision-7--reproducible-build--signingota-model)
9. [The guest-image distribution GATE](#9-the-guest-image-distribution-gate)
10. [HYPERV-SEC-01 — Hyper-V/WHPX + anti-cheat](#10-hyperv-sec-01--hyper-vwhpx--anti-cheat)
11. [Milestone gate spine reconciliation (G3 preserved)](#11-milestone-gate-spine-reconciliation-g3-preserved)
12. [M1 exit criteria (what unblocks M2)](#12-m1-exit-criteria-what-unblocks-m2)
13. [Open questions carried into M2+](#13-open-questions-carried-into-m2)

---

## 0. Purpose, scope & the milestone gate spine

**Why M1 exists.** M0 proved the *host* can assemble a correct, verified QEMU+WHPX boot command (accel, OVMF family safety, GPU fallback ordering, ADB loopback, DryRun isolation — all under a durable regression suite). That is necessary but **not** license, provenance, or architecture sign-off for the *Android runtime we boot*. M1 is the gate that establishes those foundations, so the runtime is built on decided ground rather than discovered constraints.

**In scope (this document):** the seven runtime-architecture sub-decisions, each recorded with **DECIDED** or **OPEN** status, rationale, alternatives considered, and dated evidence. **Out of scope:** any `host/` or `guest/` implementation, any image build execution, any commit of runtime code. M1 is a decision artifact.

**The milestone gate spine** (the review's gate progression, adopted as the authoritative sequencing):

| Gate | Name | Meaning | Status |
|---|---|---|---|
| **M0** | Launcher Foundation | Host can boot a guest correctly & verifiably | **ACCEPTED** ✅ |
| **M1** | Runtime Source & Build Architecture | Guest-image / provenance / kernel / graphics / compat / licensing decided | **ACCEPTED ✅** (`2026-09-24`) — this document |
| **M2** | Guest Boot Proof | A pinned guest image reaches `sys.boot_completed=1` under the launcher | **AUTHORIZED, IN EXECUTION** — X1 done, X2–X5 open |
| **M3** | Graphics Proof | Accelerated GPU path (or its decided gate resolution) renders | gated on M2 |
| **M4** | Runtime Integration | ADB/control-plane + in-guest windowing wired | gated on M3 |
| **M5** | Compatibility | ARM/native-bridge (optional) + app-compat matrix | gated on M4 |
| **M6** | Production Runtime | Signed image, OTA, installer, host integration | gated on M5 |

This spine is **reconciled** with the existing `PLAN.md` M0–M8 feature roadmap in [§11](#11-milestone-gate-spine-reconciliation-g3-preserved) — the WSA-parity per-app-native-window feature (`PLAN.md` M5 / success criterion **G3**) is **preserved as a named deliverable**, mapped into the M4→M6 band, not dropped.

---

## 1. Decision ledger (authoritative status board)

Verbatim from the accepted review, extended with the M1 sub-decision outcomes below. This ledger is the single source of truth for "what is settled vs. what is still at risk."

| Item | Status |
|---|---|
| M0 Launcher implementation | **ACCEPTED** |
| M0 adversarial corrections (A–G) | **ACCEPTED** |
| M0 durable regression suite | **ACCEPTED** |
| QEMU command generation | **VERIFIED** |
| WHPX acceleration selection | **VERIFIED** |
| ADB loopback binding (`127.0.0.1:58526`) | **VERIFIED** |
| DryRun isolation (side-effect-free) | **VERIFIED** |
| OVMF family safety (no cross-family / no split-combined) | **VERIFIED** |
| GPU fallback ordering | **VERIFIED** |
| ARM compatibility | **OPEN RISK** |
| Hyper-V anti-cheat interaction | **OPEN HOST COMPATIBILITY** (`HYPERV-SEC-01`) |
| Guest image strategy | **OPEN ARCHITECTURE GATE** → resolved [§9](#9-the-guest-image-distribution-gate) |
| Native runtime | **NOT STARTED** |
| Production release | **NOT AUTHORIZED** |
| — M1 additions ↓ | |
| Guest base / lineage (Bliss `arcadia-x86` v1) | **DECIDED** ([§2](#2-sub-decision-1--guest-base--source-lineage)) |
| Kernel (android-generic "Zenith" = Linux 6.18) | **DECIDED** ([§3](#3-sub-decision-2--kernel-strategy)) |
| Graphics baseline (SwiftShader-first) | **DECIDED**; accelerated path `GRFX-GATE-01` **OPEN** ([§4](#4-sub-decision-3--graphics-stack-the-plan-changing-finding)) |
| Native-bridge posture (x86_64 baseline; ARM optional) | **DECIDED**; ARM backend **OPEN RISK** ([§5](#5-sub-decision-4--native-bridge-boundary-arm--optional-layer)) |
| GMS boundary (GMS-free default) | **DECIDED** ([§6](#6-sub-decision-5--gms-boundary)) |
| Provenance (SBOM + SLSA) | **DECIDED** ([§7](#7-sub-decision-6--provenance--attestation)) |
| Reproducible-build & signing/OTA | **DECIDED** ([§8](#8-sub-decision-7--reproducible-build--signingota-model)) |

---

## 2. Sub-decision 1 — Guest base & source lineage

**The 2026 lineage landscape (research-confirmed):**

- **Android-x86 (the original project) is DEAD.** Last real release ~2022, stuck on Android 9; not a viable base. Its *legacy* — grub/ESP boot, first-stage ramdisk, `fstab.<hw>`, `androidboot.hardware`, HAL shims — lives on as the *technique* every x86 Android now uses to boot on PC firmware. **[H]**
- **Android-Generic Project (AGP) is the live bring-up/overlay framework** (`vendor_ag`, AGPM, kernel trees). It is *not* an OS; it is the patch/overlay machinery that turns an AOSP tree into a bootable-on-PC image. **BlissOS x86 builds through AGP.** **[H]**
- **BlissOS / BlissRoms-x86 is the most actively maintained x86_64 base.** `arcadia-x86` (Bliss OS 16.x = **Android 13**) is the **default and only active branch** (manifest updated 2026-04-12). A 2026 reorg placed it under **BlissLabs** (commercial arm Navotpala Tech, "Bass OS" / "BASS" umbrella). **Trust the manifest and live branches over `docs.blissos.org`, which is stale.** **[H]**
- **PrimeOS (Android 11, less open) and Phoenix OS (dead 2023)** are not candidates. **[M]**
- **AOSP `aosp_x86_64` GSI is now Android 16** — the cleanest upstream, but see the Plan-B downgrade below. **[H]**

### Decision

- **v1 base = BlissOS `arcadia-x86`.** The value is not "Bliss the product" but the **bundled, already-working AGP boot layer**: PC kernel + initrd + GRUB/ESP + `fstab` + HALs + a Mesa/virtio-gpu graphics fork that boots under QEMU today. Adopting it is the fastest route to a booting, GPU-capable Android-x86_64 guest, and it is Apache-2.0-cored (kernel GPL-2.0 isolated in the guest image — see [`LICENSING.md`](LICENSING.md) §4).
- **Plan-B = AOSP `aosp_x86_64` GSI (Android 16) — DOWNGRADED to a boot-layer build effort, NOT a drop-in image.** Research finding: a **plain GSI does not boot in vanilla QEMU** (signal-6 / FirstStageMount failure). It requires the *same* Android-x86/AGP boot layer Bliss already ships — GRUB/ESP or kernel+initrd, a first-stage ramdisk, `fstab.<hw>`, `androidboot.hardware`, HALs, and `-cpu host`. GSI Plan-B is therefore a **bring-up effort**, retained as the long-term clean-license rebase target once our overlays/HAL are stable — not a shortcut. **[H]**

### Our guest deltas (pinned patch set, not a fork)

Per droidloom's model (pinned base + targeted patches): `hwcomposer.emberbird` + gralloc bridge, NativeBridge wiring, freeform-on-by-default, a first-boot provisioning service, and SystemUI clipboard/notification adapters — living in `image/patches/` against the pinned `arcadia-x86` manifest revision recorded in [`image/manifest/arcadia-x86.pin.json`](../image/manifest/arcadia-x86.pin.json) (SHA `98a0a79cfffbb2cb9eb43dbaf5575a0195162bcf`, resolved 2026-09-23). *This anchors the manifest-repository revision; the fully-resolved per-project revision lock is produced at M2 build time (`repo manifest -r -o pinned.xml`) and committed alongside as `arcadia-x86.pinned.xml`.*

### Build recipe (recorded, not executed)

```
repo init -u https://github.com/BlissRoms-x86/manifest.git -b arcadia-x86 --git-lfs
repo sync -c -j"$(nproc)"
. build/envsetup.sh
lunch bliss_x86_64-userdebug
make blissify iso_img      # or: make iso_img
```

Variants: `BLISS_BUILD_VARIANT` = `vanilla` / `gapps` / `foss`; `BLISS_SPECIAL_VARIANT` = `-jupiter` / `-surface`. **We build `foss`/`vanilla`** (no bundled Google APKs — see [§6](#6-sub-decision-5--gms-boundary)). **[H]**

**Status: DECIDED.** Open sub-item: the eventual GSI-clean-rebase cutover point is tracked as a build-time decision (M6 band), not an M1 blocker.

---

## 3. Sub-decision 2 — Kernel strategy

**Correction to prior records:** the android-generic PC kernel codename is now **"Zenith" = Linux 6.18** (`android-generic/kernel-zenith`, a GKI / Android Common Kernel fork). This **supersedes the earlier note of "Crimson ~6.6"**, which was stale. **[H]**

### Decision

- **Use the android-generic "Zenith" (Linux 6.18, GKI/ACK fork) kernel shipped with `arcadia-x86` — do not roll our own.** It already carries the binder, virtio, and PC-hardware config an x86_64 Android guest needs, tracked against Android 16-era GKI.
- **binder via `binderfs`** (`CONFIG_ANDROID_BINDER_IPC` + `CONFIG_ANDROID_BINDERFS`) **+ `memfd`.** `ashmem` is deprecated/removed on modern kernels — the guest must use the binderfs+memfd path, not legacy ashmem. **[H]**
- **virtio built-in:** `virtio-gpu`, `virtio-blk`, `virtio-net`, `virtio-snd`, `virtio-input`, `vsock` — all compiled in so the launcher's device model has kernel support without module-load races at first stage.
- **CPU model under WHPX = `-cpu host` (or `max`), never a fixed/generic model.** Research-confirmed highest-risk item: a generic `-cpu` crashes Android native libraries — the Cuttlefish precedent is a **SIGILL in `libcrypto`/BoringSSL** on AVX/SHA-NI paths when the exposed CPU lacks features the prebuilt libs assume. `-cpu host` passes the real feature set through WHPX and avoids the class entirely. This is a **kernel/CPU-exposure architecture decision**, and it aligns with the M0 launcher's WHPX configuration. **[H]**

**Status: DECIDED.**

---

## 4. Sub-decision 3 — Graphics stack (the plan-changing finding)

This is the sub-decision the research **changed most**. The prior plan assumed the accelerated path (`virtio-gpu-rutabaga,gfxstream-vulkan=on` → `gfxstream_backend` → D3D12/Vulkan on Windows) was assemblable from off-the-shelf parts. **It is not, on a stock 2026 QEMU-for-Windows.**

### The finding

- Mainline QEMU rutabaga/gfxstream is real (landed ~8.1/8.2) but is **Linux-host / crosvm-oriented**; Android guests are served only through the **experimental** capsets `x-gfxstream-gles` / `x-gfxstream-composer`. **[H]**
- **The official QEMU-for-Windows build (weilnetz w64) ships with GPU acceleration disabled.** [QEMU GitLab issue #564](https://gitlab.com/qemu-project/qemu/-/issues/564) confirms the stock Windows binary has **OpenGL / virgl / Vulkan disabled** ("OpenGL support is disabled") — the GL-accelerated `virtio-gpu` variants are not compiled in, so a stock Windows binary exposes only software `virtio-gpu-pci` (**2D / software**). *(That `rutabaga`/`gfxstream` specifically are also absent is the direct corollary — the same build omits the accelerated GPU stack — an inference from #564's scope, not a separate line-item named in it.)* Verified 2026-09-23. **[H]** for the disabled-GL fact; **[H-inferred]** for the rutabaga/gfxstream-absent corollary.
- Real acceleration therefore requires **either**:
  - **(a) a custom EmberbirdOS-QEMU-for-Windows build** linking `rutabaga_gfx_ffi` + `gfxstream_backend` (gfxstream builds on Windows via VS2019/ClangCL and renders through the host `vulkan-1.dll` + ANGLE for GLES) — **publicly undemonstrated**, meaningful build risk; **or**
  - **(b) crosvm-on-Windows**, which **officially supports a Windows host (WHPX/HAXM)** and is the **canonical rutabaga+gfxstream consumer** → the lower-risk route to real gfxstream, and it **may need pulling earlier than the planned v2** if the custom-QEMU build proves intractable. **[M]**

### Decision

- **Baseline (M2/M3, CI-ready today): SwiftShader / software rendering FIRST.** Host `vulkan-1.dll` → SwiftShader ICD; GLES via ANGLE-on-SwiftShader (SwiftShader's own GLES frontend is deprecated). This is correct, testable on GPU-less CI runners, and is exactly what the launcher's `virtio-gpu-pci` fallback rung selects against a stock binary. **DECIDED.**
- **Accelerated GPU = formal architecture gate `GRFX-GATE-01`, resolved at M3 (Graphics Proof):** *custom EmberbirdOS-QEMU-Windows (rutabaga+gfxstream)* **vs.** *pull crosvm-on-Windows forward.* Decision criteria: buildability of gfxstream-on-Windows-QEMU, capset stability for Android guests, and measured render correctness. **OPEN.**
- **Guest ICD:** primary = **AOSP gfxstream `vulkan.ranchu` + GLES-emulation libs** (most-tested, sourced from the emulator images); alternative = **Mesa `gfxstream_vk`** ("gfxstream-experimental", merged Mesa 24.3). **Do not confuse with Venus** (`virtio_icd`) — that is the Linux-guest path and is not our route. **[H]**

### Launcher implication (NOT a launcher bug)

The M0 launcher's frozen GPU device fallback order — `virtio-gpu-rutabaga` (`…,gfxstream-vulkan=on,hostmem=256M,blob=true`) → `virtio-vga-gl` → `virtio-gpu-gl-pci` → `virtio-gpu-pci` (software) — has **accelerated rungs that presuppose a custom EmberbirdOS-QEMU**. Against a stock QEMU-for-Windows binary, `-device help` will not advertise the accelerated devices and the probe **correctly degrades to software `virtio-gpu-pci`**. The launcher is behaving as designed; `GRFX-GATE-01` is what makes the top rungs *reachable*. No launcher change is warranted by this finding.

**Status: baseline DECIDED; `GRFX-GATE-01` OPEN (resolve at M3).**

---

## 5. Sub-decision 4 — Native-bridge boundary (ARM = optional layer)

**Binding posture (the review's mandate, research-confirmed):** **x86 / x86_64 is the baseline the platform is 100% valid without ARM translation.** ARM is an **optional, hot-swappable native-bridge plug-in** occupying the `libnativebridge` slot — a layer *over* the x86/x86_64 baseline, never a dependency of it. **ARM compatibility is an OPEN RISK, never presented as a delivered upstream capability.**

### The 2026 ARM-translation reality

- **Upstream AOSP Berberis is STILL riscv64→x86_64 only** (build target `sdk_phone64_x86_64_riscv64`, runtime `libberberis_riscv64.so`). **ARM / arm64 is NOT in the upstream tree.** **[H]**
- **Google's ARM64 Berberis backend exists only as the proprietary, unpublished `libndk_translation.so`** in Google-APIs emulator images (A14→A17 / API 37; symbols `berberis::intrinsics::Arm64ReadFpcr/Fpsr`; ships `cpuinfo.arm64.txt`, `berberis_arm_or_arm64.rc`, `arm64_dyn` / `arm64_exe` binfmt_misc). Live via community prebuilts, but **redistribution is legally gray** — treated exactly like GApps: **user-supplied at runtime, never in source control.** **[H]**
- **Digitalis** (`DigitalisX64/digitalis`, digitalisx64.github.io, 2026-09-13) is an **open ARM64 backend built on the Apache-2.0 Berberis framework** (AOSP 16 / API 36; interpreter → lite-JIT → optimizing-JIT; 21 proxy libs). It is **the most license-plausible open ARM path — to watch**, but young and unproven. (The "Teto" fork / commit `917021cf` droidloom historically pinned could not be re-located by name in 2026.) **[M]**
- **libhoudini is DEAD** (Intel, Android-11-era, x86_64) — mismatched with an Android-13+ guest; not a forward path. **[H]**
- Context: **WSA was discontinued 2025-03-05** (it used Intel Bridge). **Google Play Games on PC** = x86_64 VM + native-bridge, x86-64 preferred, Intel/AMD-only. **[H]**

### NativeBridge contract (stable, arch-agnostic wiring)

`ro.dalvik.vm.native.bridge=<lib>.so`, `ro.dalvik.vm.isa.arm=x86`, `ro.dalvik.vm.isa.arm64=x86_64`, `ro.enable.native.bridge.exec=1` (+ `exec64`), `ro.zygote=zygote64_32`, `binfmt_misc` `arm64_dyn` / `arm64_exe`; build with `WITH_NATIVE_BRIDGE := true`. The `guest/nativebridge/` slot ships **empty by default** and accepts a translator drop-in.

### Decision

- **Default translator = none.** Baseline guest runs x86/x86_64 native code directly; ARM-only APKs simply report unsupported until a bridge is installed.
- **Preferred open ARM path = Digitalis (watch/evaluate at M5).** Proprietary `libndk_translation` = **optional, user-supplied** fallback with an in-product notice, same posture as GApps.
- **Out of scope (reverse direction):** Box64/Box86/FEX/Box64Droid are x86→ARM — irrelevant here.

**Status: posture DECIDED; ARM backend OPEN RISK (M5). The runtime architecture is valid and complete without it.**

---

## 6. Sub-decision 5 — GMS boundary

### Decision

- **Ship GMS-FREE by default.** No Google Play Services, no GApps in any distributed image. This is the license-clean, attestation-honest default.
- **microG is a first-class opt-in** — but it requires a **CURRENT, microG-scoped signature-spoofing patch in `frameworks/base`**. Google changed signature-checking in **November 2024**; the legacy patchers (NanoDroid, Tingle, Haystack) are **dead** and only work on pre-Android-9. The modern approach is the one LineageOS-for-microG / CalyxOS / DivestOS carry. x86_64 / Bliss is **no arch blocker** — the patch is arch-agnostic. **[H/M]**
- **GApps are strictly USER-SUPPLIED** — OpenGApps / LineageOS licenses forbid bundling Google APKs. Same posture as the proprietary ARM translators: documented drop-in path, in-product notice, never in source control. **[H]**
- **Play Integrity DEVICE / STRONG is structurally impossible in this VM** — there is no TEE / StrongBox with a Google-provisioned attestation key, and hardware-backed keys have been required since **May 2025**. BASIC spoofing is fragile and ToS-violating. **We document the resulting compatibility gap** (banking apps, DRM/Widevine L1, anti-cheat) rather than fight it. This is a *disclosed limitation*, matching WSA/Waydroid, not a defect to engineer around. **[H]**

**Status: DECIDED.**

---

## 7. Sub-decision 6 — Provenance & attestation

### Decision

- **SBOM is native and mandatory:** AOSP's built-in **SPDX SBOM generation (`m sbom`)** produces a per-image SBOM for both host distribution and guest image. **[H]**
- **Supply-chain integrity via SLSA + Sigstore at CI:** target **SLSA L2 now** (signed provenance, hosted build service), **L3 once a hermetic builder is in place**. Use `slsa-github-generator` for provenance and **cosign / Sigstore** for artifact signing; **in-toto** attestations bind source→build→artifact. **[M]**
- These are CI/release-plumbing decisions with **no runtime code dependency** — they can be stood up alongside the first image build and gate M6 (Production Runtime), not M2.

**Status: DECIDED.**

---

## 8. Sub-decision 7 — Reproducible-build & signing/OTA model

### Reproducibility target

- **AOSP is deterministic-ish, NOT bit-for-bit.** The Soong → Kati/Ninja pipeline (the Bazel migration was never completed) leaves nondeterminism in timestamps/fingerprints, ZIP-entry order, absolute paths, and prebuilt vendor blobs. **[H]**
- **Target = pinned-manifest / rebuilder-verifiable reproducibility, NOT bit-identical.** (AXP.OS reaches "~99%".) Mechanism: **pin manifest SHAs + a pinned prebuilt toolchain + `SOURCE_DATE_EPOCH` / `BUILD_DATETIME`.** A second independent build reproducing the same artifacts (modulo the known-nondeterministic set) is the acceptance bar. **[M]**

### Signing & OTA

- **AVB / vbmeta** for verified boot; **release + OTA signing keys held offline / in an HSM** via `--signing-helper`. **[H]**
- **A/B partitions** → atomic update + rollback. **[H]**
- **Self-hosted OTA via `avbroot` + `Custota`.** **[M]**
- **VM caveat:** AVB is **integrity-advisory only unless anchored in the guest UEFI / host** — in a VM without a hardware root of trust it verifies structure, not a hardware-attested chain. Document this alongside the Play Integrity gap ([§6](#6-sub-decision-5--gms-boundary)). **[H]**

**Status: DECIDED.**

---

## 9. The guest-image distribution GATE

The review flagged **guest-image strategy (build-from-manifest vs. signed prebuilt) as an OPEN ARCHITECTURE GATE.** Research resolves it — and the resolution is **both/and, not either/or**:

- **Build-from-pinned-manifest = the DEFAULT and the provenance anchor.** It distributes no third-party binaries (cleanest per-component license posture — see [`LICENSING.md`](LICENSING.md) §4 option 1), and it *is* the reproducibility/SBOM mechanism of [§7](#7-sub-decision-6--provenance--attestation)/[§8](#8-sub-decision-7--reproducible-build--signingota-model). This is the license and provenance root of trust.
- **Signed prebuilt image download = the USABILITY layer, built on top of the anchor.** For users who won't run a multi-hour AOSP build, we host a **signed** image *produced by the pinned-manifest build*, and then meet the GPL/LGPL obligations it triggers: publish the corresponding source (kernel + GPL components), a complete `NOTICE` / `THIRD_PARTY.md`, and honor the source-availability offer (see [`LICENSING.md`](LICENSING.md) §4 option 2 + §6).

**Gate resolution:** ship **both** — build-from-manifest as the default/anchor, signed-prebuilt as the convenience path derived from it. This supersedes `PLAN.md` §12 Q8's "vs." framing. The prebuilt path's per-component license compliance is a **build-step obligation**, not an open question.

**Status: GATE RESOLVED (both/and).**

---

## 10. HYPERV-SEC-01 — Hyper-V/WHPX + anti-cheat

**Recorded as `HYPERV-SEC-01`: OPEN HOST COMPATIBILITY.**

Enabling WHPX makes Windows itself run atop the Microsoft hypervisor. Kernel-level anti-cheat (Vanguard / EAC / BattlEye in strict mode) may refuse to run on such a host. This is a **host-environment interaction we do not control**, and it is tracked as an open compatibility item — not a solved problem and not a defect in Emberbird.

**Binding constraint on behavior:** `bcdedit /set hypervisorlaunchtype off` (reboot) is an **OPERATOR-LEVEL option** the *user* may choose — it is **NEVER** invoked silently or automatically as part of Emberbird's normal runtime behavior. Emberbird documents the toggle and starts/stops cleanly so a user can make the trade-off per session; it never edits the host boot configuration on the user's behalf. Disabling the hypervisor also disables WSL2/Hyper-V/WSA-class features for that boot — a system-wide consequence that is the operator's decision to make, with informed consent, never the runtime's.

**Status: OPEN HOST COMPATIBILITY (documented, operator-controlled, never silent).**

---

## 11. Milestone gate spine reconciliation (G3 preserved)

The review's gate spine (M0→M6) is a **provenance/architecture ordering**; `PLAN.md`'s M0–M8 is a **feature-delivery roadmap**. They are two lenses on the same program, reconciled below. **The per-app-native-window WSA-parity feature — `PLAN.md` M5 / success criterion G3, the actual product goal — is a named deliverable inside the reconciled taxonomy (M4→M6 band). It is explicitly NOT dropped**, even though the review's spine does not name it by feature.

| Review gate | PLAN.md milestone(s) | Success criteria served | Key architecture (this doc) |
|---|---|---|---|
| **M0** Launcher Foundation ✅ | M0 host bring-up ✅ | (host prereq) | verified launcher + regression suite |
| **M1** Runtime Source & Build Architecture | *(new — this document)* | governs G1–G7 | §2–§10 all sub-decisions |
| **M2** Guest Boot Proof | M0→M1 (boot a pinned image) | **G1** | §2 Bliss `arcadia-x86` · §3 Zenith/6.18 · `-cpu host` |
| **M3** Graphics Proof | M3 gfxstream | **G4** | §4 SwiftShader-first + `GRFX-GATE-01` |
| **M4** Runtime Integration | M1 ADB/ctl · M2 stream · M4 in-guest freeform | **G2, G6, G7**, partial **G3** | ADB loopback · freeform windowing |
| **M5** Compatibility | **M5 per-app windows (WSA parity — G3 headline)** · M7 ARM | **G3 (full), G5** | RDP-RAIL per-app windows · §5 optional native-bridge |
| **M6** Production Runtime | M6 host integration/installer · M8 crosvm v2 | all G, hardened | §7–§9 SBOM/SLSA/signing/OTA · §4 crosvm option |

**Reading:** WSA parity (G3) lands in the **review-M5 (Compatibility) band**, carried from `PLAN.md` M5, and is the headline demo — two Android apps as two native, independently-resizable Windows windows. The review's spine reorders *when we prove provenance*; it does not remove *what we ship*.

---

## 12. M1 exit criteria (what unblocks M2)

M1 is complete — and M2 (Guest Boot Proof) may begin — when **all** of the following are true:

1. **Guest base pinned:** the `arcadia-x86` manifest revision SHA `98a0a79cfffbb2cb9eb43dbaf5575a0195162bcf` is recorded in [`image/manifest/arcadia-x86.pin.json`](../image/manifest/arcadia-x86.pin.json) (resolved via `git ls-remote` 2026-09-23; also the repo default `HEAD`), with the GSI-Plan-B target documented as a bring-up effort. *Scope: this pins the manifest-repository revision; the per-project revision lock (`repo manifest -r`) is an M2 sync-time artifact.* — evidence recorded (§2)
2. **Kernel decided:** Zenith/6.18 adopted; binderfs+memfd; `-cpu host` under WHPX. ✅ (§3)
3. **Graphics posture decided:** SwiftShader-first baseline confirmed CI-runnable; `GRFX-GATE-01` framed with decision criteria for M3. ✅ (§4)
4. **Native-bridge slot defined:** empty-by-default `libnativebridge` contract; ARM optional; baseline valid without it. ✅ (§5)
5. **GMS boundary decided:** GMS-free default; microG opt-in with current sig-spoof patch; GApps user-supplied; Play Integrity gap documented. ✅ (§6)
6. **Provenance & reproducibility decided:** SBOM (`m sbom`) + SLSA L2→L3 + pinned-manifest reproducibility + AVB/A-B/OTA. ✅ (§7–§8)
7. **Guest-image gate resolved:** build-from-manifest (anchor) + signed-prebuilt (usability). ✅ (§9)
8. **HYPERV-SEC-01 recorded** as open host compatibility with the operator-level / never-silent constraint. ✅ (§10)
9. **Ledger & docs reflect the freeze:** decision ledger current; `PLAN.md` / `README.md` carry the governance rule and reconciled spine. ✅ (this pass)

**Evidence for all nine criteria is presented above and in the accompanying `PLAN.md` / `README.md` / `image/manifest/` artifacts. This document *records that evidence* — it does not self-certify the gate.** The M1 acceptance verdict is the owner's to make; nothing here should be read as declaring M1 accepted. M2 (Guest Boot Proof) remains gated on explicit owner sign-off per the governance rule.

**Update (`2026-09-23`):** an independent architectural/acceptance review of this artifact returned **PASS — evidence closure achieved, recommending owner acceptance**, and found no unresolved defects.

**Update (`2026-09-24`) — M1 ACCEPTED; gate closed.** The owner accepted this architecture, closing the governance gate above the runtime build. Consequences, recorded so the ledger stays authoritative:

- **M2 (Guest Boot Proof) is authorized and in execution** ([`M2-GUEST-BOOT-PROOF.md`](M2-GUEST-BOOT-PROOF.md)): its **X1** per-project lock ([`../image/manifest/arcadia-x86.pinned.xml`](../image/manifest/arcadia-x86.pinned.xml), 1183 projects, 0 unresolved) is complete, was re-derived and **byte-verified** by its restored generator ([`../tools/manifest/resolve-manifest-lock.py`](../tools/manifest/resolve-manifest-lock.py)), and is guarded locally and in CI.
- **X2–X5 remain open** and are host/runner-dependent: the from-source guest build needs ~300+ GB free (local M2 host: ~104 GB), so it moves to CI; boot/UI/ADB evidence then needs a QEMU+OVMF-provisioned Windows host. Nothing in this document's decisions is weakened by that.
- **Acceptance does not authorize `host/` or `guest/` runtime code.** Per the binding rule in [§0](#0-purpose-scope--the-milestone-gate-spine), what M2 may do is prove the boot; the production runtime stays behind the later spine gates.

---

## 13. Open questions carried into M2+

Deliberately deferred to the milestone where evidence appears — tracked, not blocking:

1. **`GRFX-GATE-01`** — custom EmberbirdOS-QEMU-Windows (rutabaga+gfxstream) vs. pull crosvm-on-Windows forward. *(resolve at M3)*
2. **ARM backend** — Digitalis maturity vs. user-supplied `libndk_translation`; per-app compat matrix. *(M5, OPEN RISK)*
3. **microG sig-spoof patch** — pick and pin the current-era implementation (LineageOS-for-microG / CalyxOS lineage). *(M4/M5)*
4. **GSI clean-rebase cutover** — when to migrate from Bliss `arcadia-x86` to an AOSP-16 GSI boot-layer build. *(M6 band)*
5. **Reproducibility %** — how close to bit-identical the pinned-manifest build gets, and which nondeterministic sources to suppress. *(M6)*
6. **SLSA L3 hermetic builder** — infrastructure to move L2→L3. *(M6)*

---

## Evidence appendix

All findings below are drawn from four 2026-current research passes; confidence tags follow [`RESEARCH-SYNTHESIS.md`](RESEARCH-SYNTHESIS.md) conventions (**[H]** confirmed in first-party source/docs · **[M]** multiple secondary sources agree · **[L]** single/dated — verify at build).

| # | Claim | Conf. | Primary basis |
|---|---|---|---|
| E1 | Android-x86 dead ~2022 (A9); AGP is the live overlay framework; Bliss builds through AGP | [H] | AGP repos (`vendor_ag`, AGPM); Android-x86 release history |
| E2 | `arcadia-x86` = Bliss OS 16.x (A13), default+active branch; manifest revision `98a0a79` committed 2026-04-12 (`x86: Update media-driver to 25.4`, hmtheboy154) | [H] | `git ls-remote` refs/heads/arcadia-x86 == HEAD (verified 2026-09-23) + GitHub commits API; pinned in [`image/manifest/arcadia-x86.pin.json`](../image/manifest/arcadia-x86.pin.json) |
| E3 | Plain AOSP GSI does not boot in vanilla QEMU (signal-6/FirstStageMount); needs AGP boot layer + `-cpu host` | [H] | GSI-on-QEMU bring-up reports; AOSP GSI docs |
| E4 | Kernel = "Zenith" Linux 6.18 (android-generic GKI/ACK fork); binderfs+memfd; ashmem removed | [H] | `android-generic/kernel-zenith`; AOSP binderfs docs |
| E5 | Generic `-cpu` → SIGILL in BoringSSL (AVX/SHA-NI); use `-cpu host`/max under WHPX | [H] | Cuttlefish/QEMU WHPX bug reports |
| E6 | Stock QEMU-for-Windows (weilnetz w64) ships GL/virgl/Vulkan disabled → only software `virtio-gpu-pci` (rutabaga/gfxstream-absent is the direct corollary) | [H] / [H-inferred] | [QEMU GitLab issue #564](https://gitlab.com/qemu-project/qemu/-/issues/564), verified 2026-09-23 |
| E7 | Real accel needs custom QEMU-Windows (rutabaga_gfx_ffi+gfxstream) or crosvm-on-Windows (canonical consumer) | [M] | QEMU/crosvm/gfxstream build docs |
| E8 | Guest ICD `vulkan.ranchu`+GLES-emulation (tested) vs Mesa `gfxstream_vk` (merged 24.3); not Venus | [H] | AOSP gfxstream; Mesa 24.3 release notes |
| E9 | Upstream Berberis still riscv64→x86_64 only in 2026; ARM not upstream | [H] | AOSP `frameworks/libs/binary_translation` |
| E10 | Google ARM64 backend = proprietary `libndk_translation.so` (A14→A17/API37); redistribution gray | [H] | Google-APIs emulator image contents |
| E11 | Digitalis = open ARM64 backend on Apache-2.0 Berberis (AOSP16/API36); young/unproven | [M] | [`DigitalisX64/digitalis`](https://github.com/DigitalisX64/digitalis), digitalisx64.github.io (first seen 2026-09-13; existence re-verified 2026-09-23) |
| E12 | libhoudini dead (Intel, A11, x86_64); WSA discontinued 2025-03-05 | [H] | Intel/WSA EOL records |
| E13 | GMS-free default; microG needs current sig-spoof patch (Google changed Nov 2024; legacy patchers dead) | [H/M] | LineageOS-for-microG / CalyxOS patch lineage |
| E14 | Play Integrity DEVICE/STRONG impossible in VM (no TEE/HW key; HW-key required since May 2025) | [H] | Google Play Integrity API docs |
| E15 | AOSP SBOM native (`m sbom`); SLSA L2→L3 + cosign/Sigstore/in-toto at CI | [H/M] | AOSP SBOM docs; SLSA framework |
| E16 | AOSP not bit-for-bit; pin manifest+toolchain+`SOURCE_DATE_EPOCH`; ~99% (AXP.OS) | [M] | AXP.OS reproducibility reports |
| E17 | AVB/vbmeta + offline/HSM keys + A/B + avbroot/Custota; AVB integrity-advisory in VM w/o HW root | [H] | AOSP AVB docs; avbroot/Custota |

---

*End of M1 architecture. This document records the M1 architecture and its supporting evidence. An independent architectural review (`2026-09-23`) returned PASS, and the **owner accepted M1 on `2026-09-24`**, closing the gate; M2 (Guest Boot Proof) is therefore authorized and in execution at [`M2-GUEST-BOOT-PROOF.md`](M2-GUEST-BOOT-PROOF.md). No runtime `host/` or `guest/` code is authored under this milestone, and this milestone's acceptance does not authorize any.*







