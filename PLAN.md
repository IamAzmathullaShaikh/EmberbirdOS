# EmberbirdOS — Finalized Build Plan

> **An open-source Windows Subsystem for Android (WSA) equivalent.**
> Run Android apps on Windows 11, each in its own native desktop window.
>
> **Status:** Plan finalized `2026-09-23`. **M0 (launcher + adversarial corrections A–G + durable regression suite) is ACCEPTED and frozen.** **M1 — Runtime Source & Build Architecture** (a decision artifact, [`docs/M1-RUNTIME-ARCHITECTURE.md`](docs/M1-RUNTIME-ARCHITECTURE.md)) was authored, evidence-complete, PASSED independent architectural/acceptance review (`2026-09-23`), and is now **ACCEPTED BY THE OWNER (`2026-09-24`)** — the gate is signed off. **M2 — Guest Boot Proof is therefore AUTHORIZED AND IN EXECUTION** ([`docs/M2-GUEST-BOOT-PROOF.md`](docs/M2-GUEST-BOOT-PROOF.md)): X1 (per-project manifest lock) is **complete, verified reproducible, and committed**; X2–X5 (guest artifact, boot, usable UI, ADB liveness) are **host- and runner-dependent and still open** — the from-source guest build needs far more local disk than the M2 host has, so the build path is being moved to CI ([`.github/workflows/guest-build.yml`](.github/workflows/guest-build.yml)). No `host/` or `guest/` runtime code is authored, and no guest has booted yet (see [§0.1](#01-governance--milestone-gate-spine) and [§13](#13-immediate-next-actions-post-confirmation)).
> **Governance rule (binding):** *No production Native Android Runtime implementation begins merely because the launcher is green. M1 must first establish the guest-image, source provenance, kernel, graphics, compatibility, and licensing architecture.*
> **Model of record:** WSA (Microsoft, discontinued Mar 2025) + [droidloom](https://github.com/denialwm/droidloom) (Linux sibling project).
> **Supporting docs:** [`docs/M1-RUNTIME-ARCHITECTURE.md`](docs/M1-RUNTIME-ARCHITECTURE.md) · [`docs/RESEARCH-SYNTHESIS.md`](docs/RESEARCH-SYNTHESIS.md) · [`docs/REPO-MAP.md`](docs/REPO-MAP.md) · [`docs/LICENSING.md`](docs/LICENSING.md)

---

## Table of contents

0. [Governance & milestone gate spine](#01-governance--milestone-gate-spine)
1. [Executive summary](#1-executive-summary)
2. [Goal & success criteria](#2-goal--success-criteria)
3. [The model we are rebuilding (WSA)](#3-the-model-we-are-rebuilding-wsa)
4. [Architecture decision: why a VM, not a WSL2 container](#4-architecture-decision-why-a-vm-not-a-wsl2-container)
5. [System architecture](#5-system-architecture)
6. [Component design](#6-component-design)
7. [The EmberbirdOS repository layout](#7-the-emberbirdos-repository-layout)
8. [Phased roadmap & milestones](#8-phased-roadmap--milestones)
9. [Testing & verification strategy](#9-testing--verification-strategy)
10. [Licensing & distribution](#10-licensing--distribution)
11. [Risks & mitigations](#11-risks--mitigations)
12. [Open questions to resolve during build](#12-open-questions-to-resolve-during-build)
13. [Immediate next actions (post-confirmation)](#13-immediate-next-actions-post-confirmation)

---

<a id="01-governance--milestone-gate-spine"></a>

## 0.1 Governance & milestone gate spine

**M0 is ACCEPTED and frozen.** The launcher (`tools/qemu/launch-emberbird.ps1`), its adversarial corrections A–G, and its durable regression suite (`tools/qemu/tests/Test-Launcher.ps1`, 17/17 passing) are the one shipped concrete artifact. Acceptance of M0 does **not** authorize the Android runtime.

**Governance rule (binding, verbatim):** *No production Native Android Runtime implementation begins merely because the launcher is green. M1 must first establish the guest-image, source provenance, kernel, graphics, compatibility, and licensing architecture.*

### Milestone gate spine (provenance/architecture ordering)

This spine sequences *when we prove provenance*, and is reconciled with the feature roadmap in [§8](#8-phased-roadmap--milestones) below (see the reconciliation table). It does **not** replace or drop any feature — in particular the per-app-native-window WSA-parity feature (**G3**, [§8](#8-phased-roadmap--milestones) M5) is preserved as a named deliverable.

| Gate | Name | Status |
|---|---|---|
| **M0** | Launcher Foundation | **ACCEPTED** ✅ |
| **M1** | Runtime Source & Build Architecture | **ACCEPTED BY THE OWNER** ✅ (`2026-09-24`; review PASS `2026-09-23`) ([`docs/M1-RUNTIME-ARCHITECTURE.md`](docs/M1-RUNTIME-ARCHITECTURE.md)); guest pin recorded ([`image/manifest/arcadia-x86.pin.json`](image/manifest/arcadia-x86.pin.json)) |
| **M2** | Guest Boot Proof | **AUTHORIZED & IN EXECUTION** (`2026-09-24`) ([`docs/M2-GUEST-BOOT-PROOF.md`](docs/M2-GUEST-BOOT-PROOF.md)): **X1 complete + verified reproducible** ([`image/manifest/arcadia-x86.pinned.xml`](image/manifest/arcadia-x86.pinned.xml)); **X2–X5 open** (guest artifact / boot / usable UI / ADB liveness) |
| **M3** | Graphics Proof | gated on M2 |
| **M4** | Runtime Integration | gated on M3 |
| **M5** | Compatibility (incl. **G3** WSA-parity windows) | gated on M4 |
| **M6** | Production Runtime | gated on M5 |

### Decision ledger (authoritative status board)

| Item | Status |
|---|---|
| M0 Launcher implementation | **ACCEPTED** |
| M0 adversarial corrections (A–G) | **ACCEPTED** |
| M0 durable regression suite | **ACCEPTED** |
| QEMU command generation | **VERIFIED** |
| WHPX acceleration selection | **VERIFIED** |
| ADB loopback binding (`127.0.0.1:58526`) | **VERIFIED** |
| DryRun isolation (side-effect-free) | **VERIFIED** |
| OVMF family safety | **VERIFIED** |
| GPU fallback ordering | **VERIFIED** |
| ARM compatibility | **OPEN RISK** (optional layer over x86/x86_64 baseline — [§6.5](#65-arm--x86_64-translation)) |
| Hyper-V anti-cheat interaction | **OPEN HOST COMPATIBILITY** (`HYPERV-SEC-01` — [§11](#11-risks--mitigations) R1) |
| Guest image strategy | **RESOLVED** (both/and — [M1 §9](docs/M1-RUNTIME-ARCHITECTURE.md); supersedes [§12](#12-open-questions-to-resolve-during-build) Q8) |
| Guest base / kernel / graphics / native-bridge / GMS / provenance | **DECIDED** ([`docs/M1-RUNTIME-ARCHITECTURE.md`](docs/M1-RUNTIME-ARCHITECTURE.md) §2–§8) |
| M1 architectural / acceptance review | **PASS — recommends owner acceptance** (`2026-09-23`, evidence closure achieved) |
| M1 owner acceptance (the gate) | **ACCEPTED** (`2026-09-24`) — M2 unblocked |
| M2 Guest Boot Proof | **AUTHORIZED & IN EXECUTION** ([`docs/M2-GUEST-BOOT-PROOF.md`](docs/M2-GUEST-BOOT-PROOF.md)); X1 **complete + reproducible**, X2–X5 **open** |
| M2 X1 per-project manifest lock | **COMPLETE & VERIFIED** — [`image/manifest/arcadia-x86.pinned.xml`](image/manifest/arcadia-x86.pinned.xml) (1183 projects, 0 unresolved); re-derivation byte-identical ([evidence](docs/evidence/M2/x1-lock-reproducibility.txt)); CI guard [`.github/workflows/verify-provenance.yml`](.github/workflows/verify-provenance.yml) |
| M2 X2–X5 (artifact / boot / UI / ADB) | **OPEN** — needs a >300 GB build runner ([`.github/workflows/guest-build.yml`](.github/workflows/guest-build.yml)) and a QEMU+OVMF host; local disk is insufficient |
| Native runtime | **NOT STARTED** |
| Production release | **NOT AUTHORIZED** |

---

<a id="1-executive-summary"></a>

## 1. Executive summary

EmberbirdOS runs unmodified Android apps on Windows 11 with **one native Windows window per Android app**, reproducing what Microsoft's WSA delivered — on an entirely open-source stack that we control.

The finalized architecture (**Track B**) is a **lightweight Android-x86_64 virtual machine** driven by **QEMU + WHPX**, whose **graphics baseline today is software rendering (SwiftShader) over software `virtio-gpu-pci`** — the CI-ready path against a stock QEMU-for-Windows binary — with **GPU-accelerated gfxstream-over-virtio-gpu as the *target* path, gated behind `GRFX-GATE-01`** (the stock QEMU-for-Windows build ships GPU accel disabled, [issue #564](https://gitlab.com/qemu-project/qemu/-/issues/564), so acceleration requires a custom QEMU build or crosvm-on-Windows — resolved at M3; see [`docs/M1-RUNTIME-ARCHITECTURE.md`](docs/M1-RUNTIME-ARCHITECTURE.md) §4), with **per-app windows projected to Windows via an in-guest Weston compositor over RDP-RAIL/VAIL** (the exact model WSLg uses for Linux GUI apps). **x86 / x86_64 is the baseline — the platform is fully valid and complete without any ARM translation.** ARM-only apps are served by an **optional, user-supplied native-bridge translator** wired via AOSP's NativeBridge — a hot-swappable layer *over* the baseline, never a dependency of it. (2026 caveat: **upstream** AOSP Berberis is Apache-2.0 but still targets **riscv64→x86_64** only; ARM→x86_64 is *not* upstream — the open option is **Digitalis** on the Apache-2.0 Berberis framework, young/unproven, and Google's proprietary `libndk_translation` remains user-supplied like GApps. **ARM compatibility is an OPEN RISK, not a settled capability.** See [§6.5](#65-arm--x86_64-translation) and [`docs/M1-RUNTIME-ARCHITECTURE.md`](docs/M1-RUNTIME-ARCHITECTURE.md) §5.)

We reject **Track A** (a droidloom-style shared-kernel Android *container* inside a custom WSL2 kernel) as the deployment model: droidloom's zero-copy graphics core **requires a native DRM render node and forbids gfxstream/virgl/llvmpipe**, but WSL2 offers only paravirtual `/dev/dxg` graphics with a system-memory copy path — so Track A would mean re-architecting the one thing droidloom does best. droidloom instead serves as our **primary design reference**: its component decomposition, per-app-window transport protocol, HWC→Wayland bridge, and threat model are directly reusable *as design*, not as (GPL-3) code.

**Delivery philosophy (per repo `CLAUDE.md`):** ship the complete, tested, documented thing. The roadmap below is structured so that **every milestone produces a runnable, verifiable artifact** — no milestone is "just plumbing." An MVP (single-window H.264 stream over ADB) is reachable at **M2**; true WSA-parity per-app windows land at **M5**.

<a id="2-goal--success-criteria"></a>

## 2. Goal & success criteria

**Goal.** A Windows 11 user installs EmberbirdOS, opens an Android `.apk` (or picks an app from the Start Menu), and the app appears as an ordinary, resizable Windows window — with working input, sound, clipboard, file access, and GPU acceleration — without knowing a VM exists.

**Definition of done (WSA parity), each independently testable:**

| # | Capability | Acceptance test |
|---|------------|-----------------|
| G1 | Boot an Android-x86_64 guest on Windows with HW acceleration | `adb shell getprop sys.boot_completed` returns `1` within 60 s of launch |
| G2 | Install & launch arbitrary APKs | `emberbirdctl install app.apk` then launch; activity reaches `RESUMED` |
| G3 | One native Windows window per Android task | Two apps open ⇒ two independent taskbar entries / HWNDs, movable & resizable |
| G4 | GPU-accelerated rendering | A GLES/Vulkan app (e.g. a 3D game) renders ≥30 fps; `dumpsys SurfaceFlinger` shows GPU composition |
| G5 | ARM app compatibility | An `arm64-v8a`-only APK installs and runs via NativeBridge |
| G6 | Host integration | Clipboard both ways, `\\Windows` files visible in guest, audio out, Start-Menu shortcuts, ADB on a loopback port |
| G7 | Lifecycle | Start/stop/status is idempotent; guest survives app crash; clean teardown leaves no orphan processes |

**Non-goals (v1):** Play Integrity / SafetyNet attestation (structurally unsupported, like WSA/Waydroid); running while a hypervisor-hostile kernel anti-cheat is active (mutually exclusive with WHPX — see [§11](#11-risks--mitigations)); NVIDIA-specific zero-copy paths; ARM Windows hosts.

<a id="3-the-model-we-are-rebuilding-wsa"></a>

## 3. The model we are rebuilding (WSA)

WSA is the reference blueprint; understanding its shape justifies every choice below.

- **A Hyper-V "utility VM."** WSA booted a stripped x86_64 AOSP in a lightweight VM created through the **Host Compute System (HCS)** (`vmcompute.exe`), backed by the process `vmmemWSA`. WSL2, Windows Sandbox, and Windows containers use the same HCS mechanism.
- **Two host processes.** `WsaService.exe` (talks to HCS, manages guest lifecycle) and `WsaClient.exe` (host-side per-app window client + Start-Menu integration).
- **Guest images.** `system.img` / `product.img` / `vendor.img` / `system_ext.img` / `initrd.img` + a mutable `userdata.vhdx`.
- **Graphics = gfxstream.** Guest GLES/Vulkan calls were serialized over **virtio-gpu** and replayed on the Windows GPU by `gfxstream_backend.dll` (Google's Graphics Streaming Kit). **This is the same engine the Android Emulator, Cuttlefish, and Google Play Games on PC use** — and the one we adopt.
- **Windowing.** Each Android task was projected to its own Windows window (via a VAIL/GrfxRedirection-style shared-memory path).
- **Bridges.** ADB reachable on `127.0.0.1:58526`; the user profile mounted into the guest at `/sdcard/Windows`; Start-Menu tiles registered under per-package `Uninstall` keys.
- **Death.** Deprecated 2024-03-05, support ended 2025-03-05; it no longer boots on Windows 11 24H2/26100+ due to an HCS handshake regression. EmberbirdOS exists to replace it on an open stack.

**What we copy:** utility-VM shape, gfxstream graphics, per-app-window projection, ADB/file/Start-Menu bridges.
**What we change:** QEMU+WHPX instead of a private HCS handshake (documented, stable, coexists with WSL2); an in-guest Weston + RDP-RAIL projector instead of the closed VAIL client; an open guest image (BlissOS/AOSP) instead of Microsoft's; Berberis instead of Intel's bundled libhoudini.

<a id="4-architecture-decision-why-a-vm-not-a-wsl2-container"></a>

## 4. Architecture decision: why a VM, not a WSL2 container

Two candidate tracks were researched to ground truth. **Track B (VM) is chosen.** This is the single most consequential decision in the project; the reasoning is recorded here as an ADR.

### Track A — droidloom-style shared-kernel container inside a custom WSL2 kernel

droidloom runs Android as a **container** (shared kernel, Linux namespaces + binderfs + a DRM render node), giving each Android task its own Wayland `xdg_toplevel`. On Windows the only Linux kernel available is WSL2's. This track is **rejected** for one decisive reason and several supporting ones:

- **GPU (fatal).** droidloom's `android/device/droidloom-x86_64-product.json` **requires a native DRM render node + native Mesa (RadeonSI/RADV)** and sets `forbidden_fallbacks: ["gfxstream","virgl","llvmpipe","DRM card node"]`. Its zero-copy path exports **DMA-BUFs with DRM modifiers + linux-drm-syncobj timelines** straight out of SurfaceFlinger (`protocol/droidloom-host-v1.md`, "fails closed; no software/pixel-readback fallback"). Inside WSL2 there is **no** native render node: the GPU appears only as paravirtual **`/dev/dxg`** with Mesa's **d3d12** Gallium driver, and WSLg v1 is documented to round-trip frames **through system memory** (VRAM→sysmem→VRAM), not zero-copy dma-buf. Satisfying droidloom in WSL2 therefore means **rewriting its zero-copy core — i.e. discarding the reason to use droidloom at all.**
- **Kernel surface.** binder/binderfs, ashmem (or memfd shims), psi, cgroup v2, and Android-specific policies must be compiled into a **custom WSL2 kernel**. WSL2 supports custom kernels, but Waydroid-in-WSL2 is notoriously fragile, and this only gets us to the GPU wall above.
- **Isolation caveat.** droidloom's own `threat-model-v1.md` states a shared-kernel cell is **explicitly not VM-equivalent** — kernel/GPU/binder vulnerabilities cross the boundary. A VM is strictly stronger isolation for running arbitrary APKs.

### Track B — Android-x86_64 VM (CHOSEN)

A real VM sidesteps every Track-A blocker and matches how WSA, the Android Emulator, Google Play Games on PC, and Cuttlefish actually ship graphics.

- **gfxstream is built for the VM boundary** — the exact inverse of droidloom's constraint. Guest GLES/Vulkan → virtio-gpu → host `gfxstream_backend` → the Windows GPU. No native render node required.
- **QEMU+WHPX coexists with Hyper-V/WSL2** (all are clients of the one Microsoft hypervisor) and boots Android-x86_64 today with a mature device model.
- **Mature open guest images exist** (BlissOS `arcadia-x86` / AOSP `aosp_x86_64` GSI) with the PC kernel, Mesa/DRM, freeform windowing, and gfxstream already integrated.
- **WSLg proves the windowing model** — in-guest Weston + RDP-RAIL to `mstsc.exe` gives per-app Windows windows, Start-Menu shortcuts, clipboard, and audio for free.

### Decision matrix

| Criterion | Track A (WSL2 container) | Track B (VM) — **chosen** |
|-----------|--------------------------|---------------------------|
| GPU acceleration on Windows | ✗ blocked (no native render node; droidloom forbids gfxstream) | ✓ gfxstream/virtio-gpu — the WSA / Play Games model (host accel gated by `GRFX-GATE-01`; SwiftShader software baseline until then) |
| Reuse droidloom **code** | ✗ requires gutting its zero-copy core | n/a (reuse its **design**) |
| Per-app windows | Possible (Wayland) but graphics-blocked | ✓ Weston + RDP-RAIL (WSLg model) |
| Isolation for arbitrary APKs | Weaker (shared kernel) | ✓ VM boundary |
| Coexist with WSL2/Hyper-V | Same kernel | ✓ WHPX client |
| Effort to first pixels | High (custom kernel + GPU rewrite) | Medium (assemble known parts) |
| Precedent | Waydroid (Linux only) | **WSA, Play Games, Emulator, Cuttlefish** |

**Consequences.** We adopt gfxstream (accepting a possible ~copy-tax vs. bare-metal zero-copy); we take a VM's memory/boot overhead over a container's; and we inherit the **hard anti-cheat constraint** ([§11](#11-risks--mitigations)). droidloom is demoted from "engine" to "the best available blueprint," which also **avoids GPL-3 relicensing** of our stack ([§10](#10-licensing--distribution)).

<a id="5-system-architecture"></a>

## 5. System architecture

```
  WINDOWS 11 HOST                                              ANDROID-x86_64 GUEST (VM)
 ┌───────────────────────────────────────────┐              ┌────────────────────────────────────────┐
 │  emberbirdctl (CLI)   Start-Menu shortcuts │              │  Android framework (BlissOS/AOSP A13+)   │
 │        │                     ▲             │              │  ┌────────────┐   ┌───────────────────┐  │
 │        ▼                     │             │              │  │ Launcher/  │   │ App  App  App ... │  │
 │  ┌──────────────┐   ┌────────┴─────────┐   │              │  │ Taskbar    │   │ (each = 1 task)   │  │
 │  │ Supervisor   │   │ mstsc.exe (RAIL) │◀──┼──RDP/RAIL────┼──┤            │   └─────────┬─────────┘  │
 │  │ (host daemon)│   │  per-app HWNDs   │   │  (VAIL shm)  │  └────────────┘   SurfaceFlinger          │
 │  └──────┬───────┘   └──────────────────┘   │              │        ▲               │ layers          │
 │         │  HCS/WHPX control                │              │  FreeRDP server        ▼                 │
 │         ▼                                  │              │  (in-guest Weston + RAIL-shell)          │
 │  ┌───────────────────────────────────┐    │              │        ▲   Wayland surface / app         │
 │  │  QEMU  (-accel whpx)              │    │              │  ┌─────┴───────────────────────────┐    │
 │  │  ┌─────────────┐  ┌─────────────┐ │    │              │  │ hwcomposer.emberbird + gralloc   │    │
 │  │  │virtio-gpu-  │  │virtio-net,  │ │    │              │  │  (posts each layer as a surface) │    │
 │  │  │rutabaga     │  │-blk,-vsock, │ │    │              │  └──────────────┬───────────────────┘    │
 │  │  │(gfxstream)  │  │-snd,-input  │ │◀───┼──virtio──────┼──── gfxstream guest ICD (GLES/VK)        │
 │  │  └──────┬──────┘  └─────────────┘ │    │              │  ┌──────────────┴───────────────────┐    │
 │  └─────────┼─────────────────────────┘    │              │  │ NativeBridge → Berberis (ARM→x86)│    │
 │            ▼ gfxstream_backend → ANGLE/D3D12│              │  └──────────────────────────────────┘    │
 │        Windows GPU (D3D12 / Vulkan)        │              │  Linux kernel (PC kernel + binder)       │
 └───────────────────────────────────────────┘              └────────────────────────────────────────┘
       ADB  (loopback :58526) ◀───────────── virtio-net user/vsock ──────────────▶  adbd :5555
       Files \\Windows profile ◀──────────── virtio-fs / 9p ──────────────────────▶  /sdcard/Windows
       Clipboard / Audio      ◀───────────── RDP virtual channels ────────────────▶  SystemUI adapter
```

**Data-flow in one sentence:** the guest's `hwcomposer.emberbird` turns each Android task's composited layer(s) into a Wayland surface fed to an **in-guest Weston** whose **RDP-RAIL** backend streams that single window to **`mstsc.exe`** on Windows, while pixels are rendered by **gfxstream** on the host GPU and control/lifecycle runs over **WHPX + virtio**.

Three surface-transport options were evaluated; we ship them in order of increasing fidelity so each milestone is shippable:
1. **M2 — H.264 stream (scrcpy model):** whole-guest or single-app frame over ADB. Robust, demoable, lowest effort.
2. **M5 — RDP-RAIL (WSLg model):** per-app windows via in-guest Weston → FreeRDP → mstsc. **Primary target.**
3. **M8 — crosvm cross-domain Wayland → native Win32 compositor:** highest control, our own window host. Long-term.

<a id="6-component-design"></a>

## 6. Component design

### 6.1 Hypervisor / VMM

| | v1 (M0–M6) | v2 (M8) | Fallback |
|---|-----------|----------|----------|
| Engine | **QEMU + WHPX** | **crosvm on Windows** (WHPX/HAXM) | HCS/Hyper-V direct |
| Why | Boots Android-x86_64 today; mature device model; `virtio-gpu-rutabaga`(gfxstream) device model exists upstream — **host accel gated by `GRFX-GATE-01`, SwiftShader software baseline until then**; coexists with WSL2 | Purpose-built rutabaga/gfxstream + cross-domain Wayland proxy; Rust; minijail | Most "native" (WSA used it) but under-documented for custom guests |

- **Enable once:** `DISM /online /Enable-Feature /FeatureName:HypervisorPlatform /All` (Windows Hypervisor Platform). Confirm `WHvGetCapability` succeeds.
- **Launch shape:** `qemu-system-x86_64 -accel whpx -M q35 -smp cores=N -m SIZE -vga none -device virtio-gpu-rutabaga,gfxstream-vulkan=on,hostmem=…,blob=true -device virtio-net-pci -device virtio-blk-pci,... -device virtio-snd-pci`. Pass **`-vga none`** so q35's default emulated VGA (`default_display="std"`) isn't created as the primary console in front of the virtio-gpu device — adding a `-device virtio-gpu-*` does *not* suppress it, and legacy VGA is very slow under WHPX. On the WHPX PIC quirk: current QEMU-on-Windows already **disables the in-kernel interrupt controller by default under WHPX**, which sidesteps the documented "a legacy-PIC interrupt won't wake the guest from HLT" bug, so the default config needs no special flag. The lever that re-exposes it is `-M q35,pic=off`, and **UEFI/OVMF is the recommended firmware in that pic-off configuration** — it is *not* q35+UEFI on its own that dodges the quirk.
- **WHPX limits to design around (from QEMU docs):** MMX/SSE/AVX-in-MMIO not emulated; legacy VGA slow; optional `-accel whpx,ssd=off` for large-MMIO speedups (weakens a mitigation — off by default).
- **The Supervisor** (our Rust host daemon, droidloom-`runtime/`-inspired) owns: composing the QEMU/crosvm command line, guest lifecycle (start/stop/status, idempotent teardown), the ADB bridge, the RDP connection warm-keep, and the app catalog → Start-Menu sync.

### 6.2 Guest OS image

| Option | Base | Pros | Cons |
|--------|------|------|------|
| **A (v1 default)** | **BlissOS `arcadia-x86`** (Android 13, `github.com/BlissRoms-x86/manifest`) | Batteries-included: android-generic **"Zenith" kernel = Linux 6.18** (GKI/ACK fork), Mesa/DRM, **freeform-by-default patchset + farmerbb Taskbar**, `vulkan-cereal`/gfxstream, virtio-gpu | Heavier, patch-driven tree (Android-Generic Project overlays); mid-transition upstream |
| **B (clean rebase)** | **AOSP `aosp_x86_64` GSI** (Android 16) | Closest to upstream, cleanest license | **Not a drop-in QEMU image** — a plain GSI fails to boot in vanilla QEMU (signal-6/FirstStageMount); needs the same AGP boot layer (GRUB/ESP or kernel+initrd, first-stage ramdisk, `fstab.<hw>`, `androidboot.hardware`, HALs, `-cpu host`) Bliss already ships. A bring-up effort, not a shortcut. |

- **Decision:** start on **Bliss `arcadia-x86`** to reach a booting, windowed, GPU-accelerated guest fastest (its value is the already-working AGP boot layer + Zenith/6.18 kernel); keep the AOSP-GSI build target as the long-term clean-license rebase, understanding it is a boot-layer *build effort*, not a drop-in image. Both build with `repo init … && repo sync && . build/envsetup.sh && lunch … && m`. **CPU model must be `-cpu host`/`max` under WHPX** — a generic `-cpu` triggers SIGILL in BoringSSL (AVX/SHA-NI). Full guest-base and kernel rationale: [`docs/M1-RUNTIME-ARCHITECTURE.md`](docs/M1-RUNTIME-ARCHITECTURE.md) §2–§3.
- **Our guest deltas live as a small, pinned patch set** (droidloom's model: pinned base + targeted patches, *not* a fork): `hwcomposer.emberbird` + gralloc bridge, NativeBridge/Berberis wiring, freeform-on-by-default, a boot-time provisioning service, and the SystemUI clipboard/notification adapters.
- **Partitions:** immutable signed `system`/`system_ext`/`product`/`vendor`; mutable `userdata` (qcow2/vhdx). Ship as a versioned image artifact.

### 6.3 Graphics (gfxstream over virtio-gpu)

- **Guest side:** the gfxstream **guest ICD** provides GLES + Vulkan; `vulkan.ranchu` HAL, gfxstream gralloc/hwcomposer talk over **virtio-gpu**. BlissOS already carries `external/mesa`, `minigbm`, `drm_hwcomposer`, `virglrenderer`, and `device/generic/vulkan-cereal` (gfxstream).
- **Host side (target path, gated):** QEMU `virtio-gpu-rutabaga` (capsets `gfxstream-vulkan`, `x-gfxstream-gles`, `x-gfxstream-composer`, `cross-domain`) → `gfxstream_backend` → **ANGLE/D3D12** or native **Vulkan** on the Windows GPU. **This accelerated path is not available on a stock QEMU-for-Windows binary** ([issue #564](https://gitlab.com/qemu-project/qemu/-/issues/564) — GL/virgl/Vulkan disabled), so it is the `GRFX-GATE-01` target (custom QEMU build vs. crosvm-on-Windows, resolved at M3; see [`docs/M1-RUNTIME-ARCHITECTURE.md`](docs/M1-RUNTIME-ARCHITECTURE.md) §4).
- **Host side (baseline, today): SwiftShader software rendering** (Bliss ships `external/swiftshader`) over software `virtio-gpu-pci` — the CI-ready path that keeps headless/CI and GPU-less machines fully functional. This is the *baseline* the launcher already targets, not merely a degraded fallback.
- **Perf note:** budget for a WSLg-style system-memory copy tax at very high FPS on discrete GPUs; the crosvm cross-domain path (M8) is the route to eliminating it. This is a *performance* concern, not a *correctness* blocker — unlike droidloom's hard render-node requirement.

### 6.4 Per-app windowing (the WSA-parity feature)

The mechanism, end to end:
1. **Freeform on by default.** Declare `PackageManager.FEATURE_FREEFORM_WINDOW_MANAGEMENT`, set the `config_freeformWindowManagement` framework overlay, and enable `enable_freeform_support`. (Bliss ships a freeform-by-default patchset in its `frameworks_base`/`frameworks_native` forks — reuse the concept.) A privileged **Taskbar** (farmerbb, system app) launches each app with `ActivityOptions.setLaunchWindowingMode(WINDOWING_MODE_FREEFORM)` + `setLaunchBounds(...)` (needs `MANAGE_ACTIVITY_TASKS`).
2. **Layer → Wayland surface.** `hwcomposer.emberbird` (our HAL, Waydroid/droidloom-style) posts **each Android task's composited output as one Wayland surface** into an **in-guest Weston** running the **RAIL-Shell** (no desktop chrome). gralloc buffers are shared to Weston via dma-buf inside the guest (a normal Linux path — the VM boundary is crossed later, by RDP/gfxstream, not here).
3. **Surface → Windows window.** Weston's **RDP backend (FreeRDP server)** remotes **each window individually** over **RDP-RAIL** (pixels copied) / **VAIL** (shared memory when co-resident) to **`mstsc.exe`** launched silently on the host; the connection stays warm so new windows pop instantly. This is precisely WSLg's design; we reuse `WSLGd`-style supervision and the `WSLDVCPlugin` dynamic-virtual-channel trick to turn guest `.desktop` entries into **Start-Menu shortcuts**.
4. **Input** flows back over the same RDP channels to Weston → Android input HAL.

Why this over inventing a Win32 compositor now: it reuses Microsoft's *own* battle-tested per-window remoting, Start-Menu, clipboard, and audio channels, and is the shortest path to G3. The native-compositor route (crosvm cross-domain → Win32/DXGI) is deferred to M8 where it buys latency, not correctness.

### 6.5 ARM → x86_64 translation

> **Posture (binding):** x86/x86_64 is the baseline; **the runtime architecture is valid and complete without ARM translation.** ARM support is an **optional, hot-swappable native-bridge plug-in** in the `guest/nativebridge/` slot (empty by default) — a layer *over* the baseline, never a dependency of it. **ARM compatibility is an OPEN RISK (G5 / M5-band), never presented as a delivered upstream capability.** Full analysis: [`docs/M1-RUNTIME-ARCHITECTURE.md`](docs/M1-RUNTIME-ARCHITECTURE.md) §5.

- **NativeBridge contract (stable, arch-agnostic wiring):** `ro.dalvik.vm.native.bridge=<lib>.so`, `ro.dalvik.vm.isa.arm=x86`, `ro.dalvik.vm.isa.arm64=x86_64`, `ro.enable.native.bridge.exec[64]=1`, `ro.product.cpu.abilist*`, `ro.zygote=zygote64_32`; build with `WITH_NATIVE_BRIDGE := true`; `binfmt_misc` `arm64_dyn`/`arm64_exe` for standalone ARM ELF.
- **2026 translator reality:** **upstream AOSP Berberis is still riscv64→x86_64 only** (`sdk_phone64_x86_64_riscv64`, `libberberis_riscv64.so`) — **ARM/arm64 is not upstream.** Google's ARM64 backend exists only as the proprietary, unpublished `libndk_translation.so` (Google-APIs emulator images). The prior "Teto" fork droidloom historically pinned could not be re-located by name in 2026.
- **Preferred open ARM path = Digitalis** (`DigitalisX64/digitalis`, 2026-09-13) — an open ARM64 backend on the **Apache-2.0 Berberis framework** (AOSP 16 / API 36). Most license-plausible open route; **young and unproven — watch/evaluate at the M5 compatibility band.**
- **Fallback (optional, user-supplied at runtime — never in source control):** proprietary `libndk_translation` (Google), same drop-in posture as GApps with an in-product notice. **libhoudini is DEAD** (Intel, Android-11/x86_64) — not a forward path against an A13+ guest.
- **Reality:** expect app-by-app validation; ARM32/RenderScript/standalone-ARM-exe support is weakest.
- **Explicitly out of scope:** Box64/Box86/FEX/Box64Droid are **x86→ARM** (reverse direction) — irrelevant here.

### 6.6 Host integration

| Feature | Mechanism |
|---------|-----------|
| App launch / install / catalog | `emberbirdctl` (droidloom `droidloomctl` analog) over ADB + a guest agent; `.desktop` export → Start-Menu via RDP DVC plugin |
| Files | user profile → `/sdcard/Windows` via **virtio-fs / 9p** |
| Clipboard | Wayland `wlr-data-control` in guest ↔ RDP clipboard channel ↔ Windows clipboard |
| Notifications | guest SystemUI listener → forwarded to Windows toast (RDP channel / host daemon) |
| Audio | virtio-snd (or PulseAudio-over-RDP, WSLg-style) |
| ADB | guest `adbd` reachable on a host loopback port |

### 6.7 Hooking / shims (bhook)

- **bytedance/bhook (bytehook, MIT, supports x86_64, API 16–37)** is a **guest-side** tool, used for: sensor/GPS **injection**, compatibility shims (calls that assume real hardware / probe `/sys`,`/proc`), instrumentation (`eglSwapBuffers`/alloc tracing), and *prototyping* graphics interception.
- **Not** for the production render path — that is a real `hwcomposer`/`gralloc` HAL (§6.4). PLT/GOT hooks miss inlined/intra-`.so`/`dlsym` calls and are brittle on hot paths. Use **shadowhook** (inline) only where a non-PLT intercept is unavoidable.

<a id="7-the-emberbirdos-repository-layout"></a>

## 7. The EmberbirdOS repository layout

A single Rust-workspace-centric monorepo (droidloom's proven decomposition, retargeted to Windows):

```
EmberbirdOS/
├─ PLAN.md                     # this document
├─ README.md                   # project overview + quickstart
├─ docs/                       # RESEARCH-SYNTHESIS, REPO-MAP, LICENSING, per-component design
├─ host/                       # Windows-side Rust workspace (the "runtime")
│   ├─ supervisor/             #   guest lifecycle, WHPX/QEMU command assembly, teardown
│   ├─ emberbirdctl/           #   user CLI: start|stop|status|install|launch|apps|logs
│   ├─ catalog/                #   Android launcher activities → .desktop → Start-Menu
│   ├─ rdp-bridge/             #   FreeRDP client mgmt / mstsc warm-keep / DVC plugin host
│   └─ transport/              #   host↔guest control channel (vsock/named-pipe)
├─ guest/                      # Android-side components (Soong/Android.bp)
│   ├─ hwcomposer/             #   hwcomposer.emberbird (layer → Wayland surface)
│   ├─ gralloc/                #   buffer allocation over virtio-gpu
│   ├─ weston-rail/            #   in-guest Weston config + RAIL-shell + FreeRDP server
│   ├─ systemui-adapter/       #   clipboard + notification bridges
│   ├─ nativebridge/           #   Berberis wiring + props
│   └─ provisioning/           #   first-boot service (props, network, ADB, catalog)
├─ image/                      # guest image build: manifest pin + patch set + lunch/make wrappers
│   ├─ manifest/               #   pinned Bliss arcadia-x86 / AOSP GSI refs (+ our local manifest)
│   └─ patches/                #   targeted AOSP patches (freeform, hwc, bridge) — NOT a fork
├─ tools/
│   └─ qemu/                   #   launch-emberbird.ps1 (M0 launcher) + notes
├─ packaging/                  # MSIX / installer, image download+verify, systemd-in-guest units
└─ tests/                      # host unit/integration; guest boot/e2e; graphics/translation benches
```

**Licensing boundary:** `host/` and `guest/` are an **independent reimplementation informed by droidloom's design** — not a formal clean-room (the same engineers who read droidloom write our code; permitted reuse is limited to non-copyrightable functional elements — architecture, interfaces, protocol shapes, threat model — never its source's structure or expression), so EmberbirdOS is **not** forced to GPL-3. If any droidloom source is ever imported, that module is quarantined and the whole work goes GPL-3 (see [§10](#10-licensing--distribution)).

<a id="8-phased-roadmap--milestones"></a>

## 8. Phased roadmap & milestones

Each milestone ends in a **runnable artifact** and an **exit test**. Milestones are dependency-ordered; the MVP is usable at M2 and WSA-parity at M5.

> **Two numbering schemes — read this first.** The review's **milestone gate spine** ([§0.1](#01-governance--milestone-gate-spine): M0 Launcher → M1 *Runtime Source & Build Architecture* → M2 Guest Boot Proof → … → M6 Production Runtime) is a **provenance/architecture ordering**. The **feature roadmap below (M0–M8)** is a **delivery ordering**. They are two lenses on the same program and are reconciled cell-by-cell in [`docs/M1-RUNTIME-ARCHITECTURE.md`](docs/M1-RUNTIME-ARCHITECTURE.md) §11. The one binding consequence for this roadmap: **the review's "M1 — Runtime Source & Build Architecture" is a hard gate that sits between the shipped M0 launcher and all feature work below.** It is a *decision artifact* (now authored as [`docs/M1-RUNTIME-ARCHITECTURE.md`](docs/M1-RUNTIME-ARCHITECTURE.md)), and per the governance rule **no feature milestone below (starting with guest boot) begins until that gate is signed off.** The WSA-parity per-app-window feature remains **M5 / G3** here and is explicitly preserved (it maps into the review's M5 *Compatibility* band).

### M0 — Host bring-up & boot harness *(SHIPPED & ACCEPTED)*
- Enable WHPX; install QEMU + OVMF; write `tools/qemu/launch-emberbird.ps1` (✅ shipped, with adversarial corrections A–G and a durable 17-assertion regression suite `tools/qemu/tests/Test-Launcher.ps1`).
- Acquire a stock **BlissOS `arcadia-x86`** image (or build it) and boot it under `-accel whpx`.
- **Exit test:** the guest reaches the Android UI in QEMU; `WHvGetCapability` present; no Hyper-V conflict with an existing WSL2 install.
- **Status: ACCEPTED and frozen** ([§0.1](#01-governance--milestone-gate-spine)). This is the only artifact excepted from the runtime gate.

### ⛔ Gate — Runtime Source & Build Architecture *(review spine "M1"; authored · review PASS `2026-09-23` · awaiting owner acceptance)*
- **This is a decision artifact, not feature work** — the review's binding governance rule places it between the shipped M0 launcher and every feature milestone below. Delivered as [`docs/M1-RUNTIME-ARCHITECTURE.md`](docs/M1-RUNTIME-ARCHITECTURE.md): guest base/lineage, kernel (Zenith/6.18), graphics posture (`GRFX-GATE-01`), native-bridge boundary, GMS boundary, provenance/SBOM/SLSA, reproducible-build/signing/OTA, the guest-image gate resolution, and `HYPERV-SEC-01`.
- **Exit criteria:** the nine items in [`docs/M1-RUNTIME-ARCHITECTURE.md`](docs/M1-RUNTIME-ARCHITECTURE.md) §12 — **evidence complete; an independent architectural review returned PASS (`2026-09-23`, evidence closure achieved).** The acceptance verdict itself remains the owner's; this plan does not self-certify the gate.
- **Governance:** per the binding rule, **no feature milestone below begins until this gate is signed off by the owner.** *(Naming note: the review spine's "M1" is this gate; the feature roadmap's "M1" below is the distinct Networking/ADB milestone — the two schemes are mapped in [`docs/M1-RUNTIME-ARCHITECTURE.md`](docs/M1-RUNTIME-ARCHITECTURE.md) §11.)*

### M1 — Networking, ADB & control plane
- virtio-net up; `adbd` reachable on a host loopback port; scaffold `emberbirdctl` (`status`, `shell`, `install`, `launch`) over ADB; scaffold `supervisor` (idempotent start/stop/teardown, no orphan processes).
- **Exit test:** `emberbirdctl install app.apk && emberbirdctl launch <pkg>` drives the guest; `emberbirdctl stop` leaves zero orphaned QEMU/mstsc processes (G7 partial).

### M2 — MVP: single-window H.264 stream *(first shippable product)*
- scrcpy-model capture of the guest (or a single app) → one host window with input forwarding.
- **Exit test:** launch an app, see & interact with it in a Windows window at ≥30 fps (G1, G2, partial G3/G4).

### M3 — GPU acceleration (gfxstream)
- Bring up `virtio-gpu-rutabaga`(gfxstream) end-to-end; guest gfxstream ICD → host `gfxstream_backend` → D3D12/Vulkan; SwiftShader fallback wired for CI/GPU-less.
- **Blocking finding (`GRFX-GATE-01`, resolve here):** the **stock official QEMU-for-Windows binary ships GPU acceleration DISABLED** (QEMU GitLab issue #564, open) — it exposes only software `virtio-gpu-pci`. Accelerated rendering requires **either** a custom EmberbirdOS-QEMU-for-Windows (linking `rutabaga_gfx_ffi` + `gfxstream_backend`) **or** pulling **crosvm-on-Windows** (the canonical rutabaga/gfxstream consumer) forward from M8. The launcher's accelerated GPU rungs presuppose that custom build and **correctly degrade to software** against a stock binary — that is by design, not a bug. See [`docs/M1-RUNTIME-ARCHITECTURE.md`](docs/M1-RUNTIME-ARCHITECTURE.md) §4.
- **Exit test:** a GLES + a Vulkan sample render correctly and ≥30 fps; `dumpsys SurfaceFlinger` shows GPU composition (G4).

### M4 — Freeform windowing in-guest
- Enable freeform-by-default + Taskbar; validate multiple simultaneous freeform tasks in-guest (still shown via M2 stream or an in-guest desktop).
- **Exit test:** two apps run as two independent resizable freeform windows inside the guest.

### M5 — Per-app windows to Windows (RDP-RAIL) *(WSA parity)*
- `hwcomposer.emberbird` + gralloc post per-task Wayland surfaces to in-guest Weston (RAIL-shell); FreeRDP server → warm `mstsc.exe`; Start-Menu shortcuts via DVC plugin.
- **Exit test:** two Android apps appear as **two native Windows windows** with independent taskbar entries, movable/resizable, GPU-accelerated (G3 + G4 together — the headline demo).

### M6 — Host integration & polish
- Clipboard both ways; `\\Windows` profile at `/sdcard/Windows` (virtio-fs); audio out; notifications → Windows toasts; installer/MSIX + signed image download & verify.
- **Exit test:** G6 fully; a fresh-machine install → first app window in one guided flow.

### M7 — ARM app compatibility (Berberis)
- Wire NativeBridge + Berberis; validate an `arm64-v8a`-only APK; document per-app results; expose optional user-supplied libhoudini/libndk path.
- **Exit test:** a known ARM64-only app installs and runs (G5); translation bench recorded.

### M8 — v2 engine & performance (crosvm cross-domain)
- Evaluate crosvm-on-Windows; prototype the cross-domain Wayland → native Win32/DXGI compositor to remove the copy tax; compare latency/fps vs. RDP-RAIL.
- **Exit test:** measured latency/fps improvement over M5 on the same apps, or a documented decision to stay on RDP-RAIL.

**Rough sequencing:** M0–M2 are the fast wins (assemble known parts). M3–M5 are the technical heart (our HAL + windowing). M6 is productization. M7–M8 are compatibility & performance depth. Each is independently demoable; none is left half-wired.

<a id="9-testing--verification-strategy"></a>

## 9. Testing & verification strategy

Per the repo standard, code isn't done until it's proven. Layered strategy:

| Layer | What | Tooling | Runs where |
|---|---|---|---|
| **Unit** | Host Rust logic: transport framing, RAIL protocol codec, catalog parsing, `emberbirdctl` arg handling, supervisor state machine | `cargo test` | CI (no VM) |
| **Unit (guest)** | HAL logic: layer→surface mapping, gralloc handle math, native-bridge prop resolver | GTest / host-side unit build | CI (no VM) |
| **Golden/protocol** | RAIL & transport wire messages vs. checked-in golden byte fixtures | `cargo test` + fixtures | CI |
| **Integration (headless)** | Boot guest under QEMU with **SwiftShader** (no GPU), ADB up, install+launch a test APK, assert window/stream events | `pytest` harness driving `emberbirdctl` + QEMU | CI (GPU-less runner) |
| **Integration (GPU)** | gfxstream path renders GLES/Vulkan samples; fps/latency captured | same harness on a GPU host | nightly / self-hosted |
| **E2E scenario** | Fresh install → launch two apps → two native windows → clipboard round-trip → clean teardown (zero orphans) | scripted scenario | pre-release |
| **Compat matrix** | Curated APK set (x86_64 native, ARM64-via-Berberis, GLES, Vulkan, WebView) with per-app pass/fail | catalog-driven runner | nightly |
| **Regression** | Each fixed bug gets a test; anti-cheat/hypervisor-toggle path documented & manually verified | mixed | ongoing |

**Principles:** every milestone's exit test becomes a permanent automated check where possible; the SwiftShader path keeps the whole stack CI-testable without a GPU; no milestone is marked done on a failing suite; teardown is always asserted (orphan-process leaks are a test failure, not a nuisance).

**Fixtures:** test APKs are tiny purpose-built apps we author (a GLES triangle, a Vulkan triangle, a freeform-resize probe, an ARM64-only native lib) checked into `tests/apks/` with source — no redistribution of third-party apps.

<a id="10-licensing--distribution"></a>

## 10. Licensing & distribution

The combined-work license is the single biggest legal constraint; it drives the independent-reimplementation boundary in [§7](#7-the-emberbirdos-repository-layout).

| Input | License | Our use | Obligation |
|---|---|---|---|
| **droidloom** | GPL-3.0-or-later | **Design reference only** — read for ideas, never copy code | Reusing any source **relicenses the whole combined work GPL-3**. Quarantined. |
| **AOSP** (platform, `libnativebridge`) | Apache-2.0 | Guest platform base; our HAL/adapters link against it | Attribution; NOTICE file |
| **Berberis** | Apache-2.0 | Upstream = **riscv64→x86_64**; ARM→x86_64 only via a non-upstream fork ("Teto"); used via NativeBridge | Attribution; NOTICE |
| **BlissOS `arcadia-x86`** | AOSP-derived (Apache-2.0 core) + GPL-2.0 (kernel) + assorted per-component | Guest image v1 | Kernel & GPL bits stay isolated in the guest image; comply per-component; publish image build manifest |
| **bytehook (bhook)** | MIT | Guest-side shims/instrumentation | Attribution |
| **QEMU** | GPL-2.0 | External tool we **invoke**, do not link into our code | Ship as separate component / user-provided; no linking = no relicense of our host code |
| **Mesa / gfxstream / ANGLE / SwiftShader** | MIT/Apache-2.0/BSD-ish | Graphics stack (guest ICD / host backend) | Attribution |
| **libhoudini / libndk_translation** | Proprietary (Intel/Google) | **Never in source control**; user supplies at runtime | No redistribution; runtime-optional plugin path only |
| **OpenSSL 3.x / BoringSSL** | Apache-2.0 / OpenSSL-3 (Apache-2.0) | Crypto | Attribution |
| **EmberbirdOS host+guest source** | **Apache-2.0** (adopted — [`LICENSE`](LICENSE) + [`NOTICE`](NOTICE)) | Our code | Keeps us permissive and clear of GPL-3 (independent reimplementation, no droidloom source) |

**Distribution shape:** ship (a) our Apache-2.0 host+guest source, (b) a **build recipe + signed image** for the guest rather than a monolithic blob where per-component licenses require it, (c) QEMU as a separately-obtained/bundled GPL-2 tool invoked over its CLI, (d) proprietary translators strictly as a user-supplied runtime drop-in with an in-product notice. A full `NOTICE`/`THIRD_PARTY.md` is generated at build time. **`docs/LICENSING.md`** carries the authoritative long-form analysis.

<a id="11-risks--mitigations"></a>

## 11. Risks & mitigations

| # | Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|---|
| R1 | **`HYPERV-SEC-01` — anti-cheat / host compatibility (OPEN HOST COMPATIBILITY):** WHPX makes Windows itself run atop the Microsoft hypervisor; kernel anti-cheat (Vanguard/EAC/BE strict) may refuse such a host | High | Medium | `bcdedit /set hypervisorlaunchtype off` (reboot) is an **OPERATOR-LEVEL** option the user may choose — **NEVER invoked silently/automatically** by Emberbird's runtime. Ember documents the toggle (and its system-wide cost: disables WSL2/Hyper-V/WSA-class features that boot) and starts/stops cleanly for per-session trade-offs; defeating anti-cheat is out of scope. See [`docs/M1-RUNTIME-ARCHITECTURE.md`](docs/M1-RUNTIME-ARCHITECTURE.md) §10. |
| R2 | **gfxstream host-backend maturity on Windows** — `gfxstream_backend` + ANGLE/D3D12 path less battle-tested outside AOSP emulator | Medium | High | SwiftShader software fallback always wired; lean on the emulator's proven config; M3 is isolated so failure doesn't block M2 MVP |
| R3 | **RDP-RAIL per-app fidelity** — surface/window mapping, DPI, focus, z-order edge cases | Medium | High | Start from WSLg's proven RAIL/VAIL plumbing; M2 stream is the guaranteed fallback UX; extensive M5 window-behavior tests |
| R4 | **BlissOS image drift / opacity** — large multi-repo manifest, per-component licensing, reproducibility; `docs.blissos.org` stale vs. live branches | Medium | Medium | Pin the `arcadia-x86` manifest SHA; trust live branches over docs; keep **AOSP GSI clean-rebase** as Plan-B (a boot-layer *build effort*, not a drop-in — [§6.2](#62-guest-os-image)); publish our image build manifest + SBOM |
| R5 | **ARM translation immaturity (OPEN RISK)** — upstream Berberis is riscv64-only; open ARM path (Digitalis) is young; proprietary `libndk_translation` is user-supplied | Medium | Medium | **x86/x86_64 baseline is valid without ARM** — ARM is an optional native-bridge plug-in ([§6.5](#65-arm--x86_64-translation)); treat as M7 (not MVP); per-app compat matrix; Digitalis to watch, `libndk` optional user-supplied fallback |
| R6 | **GPL-3 contamination** from droidloom | Low | High | Hard independent-reimplementation boundary ([§7](#7-the-emberbirdos-repository-layout)/[§10](#10-licensing--distribution)); design-only reference; no source import without quarantine + relicense decision |
| R7 | **Hyper-V/WSL2 coexistence** conflicts on the user's machine | Low | Medium | WHPX is a client of the same MS hypervisor as WSL2 → coexists; M0 exit test explicitly checks a live WSL2 install |
| R8 | **Performance/latency** of copy-based transports (RDP-RAIL, H.264) | Medium | Medium | M8 crosvm cross-domain zero-copy path as the performance escape hatch; measure before/after |
| R9 | **Windows 24H2/26100+ platform shifts** breaking VMM/GPU-PV assumptions | Low | Medium | We control our own VMM (QEMU/crosvm), not WSA's HCS path; less exposed than WSA was |
| R10 | **Scope/complexity overrun** | Medium | Medium | Strict milestone gating; each Mx independently shippable; MVP value delivered at M2 long before full parity |

<a id="12-open-questions-to-resolve-during-build"></a>

## 12. Open questions to resolve during build

These are deliberately deferred to the milestone where evidence appears — not blockers on starting.

1. **gfxstream on Windows host:** ANGLE/D3D12 vs. native Vulkan for `gfxstream_backend`. **Elevated to formal gate `GRFX-GATE-01`** — the deeper finding is that the **stock QEMU-for-Windows ships accel disabled (issue #564)**, so the real choice is *custom EmberbirdOS-QEMU-Windows* vs. *crosvm-on-Windows pulled forward*. *(resolve at M3; see [`docs/M1-RUNTIME-ARCHITECTURE.md`](docs/M1-RUNTIME-ARCHITECTURE.md) §4)*
2. **RDP-RAIL reuse depth:** how much WSLg RAIL/VAIL plumbing can we reuse directly vs. reimplement? Is a public FreeRDP RAIL server sufficient, or do we need WSLg-specific extensions? *(M5)*
3. **Guest image (long-term base):** stay on BlissOS `arcadia-x86`, or rebase onto a lean AOSP GSI once our HAL/overlays are stable — noting the GSI is a *boot-layer build effort*, not a drop-in. *(evaluate by M6; base decision recorded in [`docs/M1-RUNTIME-ARCHITECTURE.md`](docs/M1-RUNTIME-ARCHITECTURE.md) §2)*
4. **Freeform trigger:** rely on BlissOS's freeform-by-default patchset, or drive windowing purely from the host via `ActivityOptions` launch bounds? *(M4/M5)*
5. **virtio-fs on Windows guest share:** confirm `\\Windows` ↔ `/sdcard/Windows` path works under QEMU-WHPX, or fall back to a different share transport. *(M6)*
6. **Native-bridge default:** ship translator-free by default (x86/x86_64 baseline) and make ARM support a purely opt-in plug-in — confirm the real-world compat gap; evaluate **Digitalis** (open) vs. user-supplied `libndk_translation`. *(M7; posture decided in [`docs/M1-RUNTIME-ARCHITECTURE.md`](docs/M1-RUNTIME-ARCHITECTURE.md) §5)*
7. **crosvm-on-Windows viability:** is the WHPX backend + rutabaga cross-domain mature enough on Windows to justify the v2 migration? *(M8)*
8. ~~**Distribution of the guest image:** signed prebuilt image download vs. local build-from-manifest~~ — **RESOLVED (both/and):** build-from-pinned-manifest is the default + provenance anchor; a **signed prebuilt** derived from it is the usability layer (meeting per-component GPL/LGPL obligations as a build step). Supersedes the "vs." framing. *(See [`docs/M1-RUNTIME-ARCHITECTURE.md`](docs/M1-RUNTIME-ARCHITECTURE.md) §9 + `docs/LICENSING.md` §4.)*

<a id="13-immediate-next-actions-post-confirmation"></a>

## 13. Immediate next actions (post-confirmation)

**Status:** the launcher foundation is ACCEPTED/frozen; the M1 architecture gate is authored, evidence-complete, passed independent architectural review (`2026-09-23`: PASS), and has been **ACCEPTED BY THE OWNER (`2026-09-24`)**. **M2 (Guest Boot Proof) is authorized and in execution.** The governance rule ([§0.1](#01-governance--milestone-gate-spine)) continues to hold for everything below M2: *no production Native Android Runtime begins merely because the launcher is green* — and the gate that satisfied it was M1, which is now signed off.

**Done (shipped in this repo):**

1. ✅ **Repo scaffolded** — `README.md`, `.gitignore`, and the planning/docs tree.
2. ✅ **M0 launcher SHIPPED & ACCEPTED** — `tools/qemu/launch-emberbird.ps1` (QEMU+WHPX boot of a BlissOS `arcadia-x86` image, `-Check`/`-DryRun` modes, adversarial corrections A–G) + `tools/qemu/README.md`, with a durable regression suite `tools/qemu/tests/Test-Launcher.ps1` (17 assertions, green).
3. ✅ **Companion docs written** — [`docs/RESEARCH-SYNTHESIS.md`](docs/RESEARCH-SYNTHESIS.md) (evidence + sources + confidence), [`docs/REPO-MAP.md`](docs/REPO-MAP.md) (per-input keep/drop verdicts), [`docs/LICENSING.md`](docs/LICENSING.md) (long-form license analysis).
4. ✅ **M1 Runtime Source & Build Architecture authored** — [`docs/M1-RUNTIME-ARCHITECTURE.md`](docs/M1-RUNTIME-ARCHITECTURE.md): guest base/lineage, kernel (Zenith = Linux 6.18), graphics gate (`GRFX-GATE-01`), native-bridge posture (x86_64 baseline / ARM optional), GMS boundary, provenance/signing, guest-image gate (both/and, resolved), `HYPERV-SEC-01`.
5. ✅ **M2 Guest Boot Proof execution spec authored** — [`docs/M2-GUEST-BOOT-PROOF.md`](docs/M2-GUEST-BOOT-PROOF.md): the tightly-scoped, evidence-first boot-proof plan (per-project manifest lock → guest artifact → boot via the frozen M0 launcher → usable-UI evidence).
6. ✅ **M1 ACCEPTED by the owner (`2026-09-24`)** — the governance gate is satisfied and M2 is unblocked.
7. ✅ **M2 X1 COMPLETE & VERIFIED** — the per-project revision lock [`image/manifest/arcadia-x86.pinned.xml`](image/manifest/arcadia-x86.pinned.xml) (1183 projects, 0 unresolved) is committed; its generator [`tools/manifest/resolve-manifest-lock.py`](tools/manifest/resolve-manifest-lock.py) was restored and re-derives the committed lock **byte-for-byte** over the network with no `repo sync` ([evidence](docs/evidence/M2/x1-lock-reproducibility.txt)); [`tools/manifest/verify-lock.py`](tools/manifest/verify-lock.py) guards it locally and in CI.
8. ✅ **M2 evidence tooling restored/authored** — [`tools/qemu/provision-host.ps1`](tools/qemu/provision-host.ps1) (host provisioning + readiness report) and the CI workstream ([`verify-provenance.yml`](.github/workflows/verify-provenance.yml), [`launcher-tests.yml`](.github/workflows/launcher-tests.yml), [`guest-build.yml`](.github/workflows/guest-build.yml)).

**▶ M2 in execution — the remaining, host/runner-dependent work:**

9. **M2 X2 (guest artifact)** — build from the locked manifest with the one shared recipe [`tools/guest-build/build-from-manifest.sh`](tools/guest-build/build-from-manifest.sh), executed **remotely on Crave** ([`docs/M2-CRAVE-BUILD.md`](docs/M2-CRAVE-BUILD.md)) or on a big-disk runner ([`guest-build.yml`](.github/workflows/guest-build.yml), `mode=build-from-manifest`). The local machine has ~104 GB free against ~300+ GB needed, so the build happens off-machine — and **no provenance-usable prebuilt exists to shortcut it** ([`docs/evidence/M2/x2-artifact-availability.txt`](docs/evidence/M2/x2-artifact-availability.txt)).
10. **M2 X3–X5 (boot, usable UI, ADB liveness)** — provision QEMU + OVMF on the Windows host ([`tools/qemu/provision-host.ps1`](tools/qemu/provision-host.ps1) `-InstallQemu` / `-FetchPlatformTools`), then boot the X2 artifact with the frozen `launch-emberbird.ps1` and capture the `sys.boot_completed=1` + `adb devices` evidence. **Blocked on that host provisioning** — see the M2 execution appendix.
11. **Then M3 (Graphics Proof)** — resolve `GRFX-GATE-01` (custom EmberbirdOS-QEMU-Windows vs. crosvm-on-Windows) on isolated hardware.
12. **Then the feature roadmap** — virtio-net + ADB + `emberbirdctl` skeleton (Rust) and onward, milestone-by-milestone per [§8](#8-phased-roadmap--milestones), each gated on its exit test, nothing left half-wired.

---

*M0 launcher foundation is ACCEPTED and frozen. The M1 architecture gate is authored, evidence-complete, passed independent review (`2026-09-23`), and was **ACCEPTED BY THE OWNER on `2026-09-24`** — so M2 (Guest Boot Proof) is authorized, and its X1 evidence is complete and verified. M2's X2–X5 evidence is still open and depends on a large-disk build runner plus a QEMU/OVMF-provisioned Windows host. No `host/` or `guest/` runtime code is authored, no guest image has been built, and no VM has booted.*
