# EmberbirdOS

**An open-source Windows Subsystem for Android.** Run Android apps on Windows 11 — ideally each in its own native desktop window — after Microsoft's WSA was discontinued (support ended 2025-03-05).

> **Status: M0 launcher foundation ACCEPTED & frozen; M1 architecture gate ACCEPTED BY THE OWNER (`2026-09-24`, after review PASS `2026-09-23`); M2 Guest Boot Proof AUTHORIZED & IN EXECUTION — X1 complete & verified, X2–X5 open.**
> The complete technical plan is in **[`PLAN.md`](PLAN.md)**; the runtime-architecture gate is **[`docs/M1-RUNTIME-ARCHITECTURE.md`](docs/M1-RUNTIME-ARCHITECTURE.md)**; the milestone now executing is **[`docs/M2-GUEST-BOOT-PROOF.md`](docs/M2-GUEST-BOOT-PROOF.md)**. Shipped so far: the **M0 boot launcher** ([`tools/qemu/`](tools/qemu/)), its 17-assertion regression suite (green), and the **M2 X1 per-project manifest lock** ([`image/manifest/arcadia-x86.pinned.xml`](image/manifest/arcadia-x86.pinned.xml), 1183 projects, 0 unresolved) with its restored, verified generator and CI guards under [`.github/workflows/`](.github/workflows/).
>
> **What M2 still needs:** X1 pinned the guest base, but X2–X5 (build/acquire the guest artifact → boot it under the frozen launcher → usable UI → ADB liveness) require a build runner with ~300+ GB free (**[`guest-build.yml`](.github/workflows/guest-build.yml)**) and a QEMU/OVMF-provisioned Windows host (**[`tools/qemu/provision-host.ps1`](tools/qemu/provision-host.ps1)**). No guest has booted yet. **No `host/` or `guest/` runtime code is authored** — the governance rule still holds for everything below M2, and the gate that satisfied it (M1) is now signed off.
>
> **Governance rule:** *No production Native Android Runtime implementation begins merely because the launcher is green. M1 must first establish the guest-image, source provenance, kernel, graphics, compatibility, and licensing architecture.* M1 did, and the owner accepted it on `2026-09-24`.

## What it is

EmberbirdOS boots a full **Android-x86_64 virtual machine** on Windows using **QEMU + WHPX** (coexists with Hyper-V/WSL2), renders on a **software (SwiftShader) baseline today** — with **GPU-accelerated gfxstream → D3D12/Vulkan across the VM boundary as the *target* path, gated by `GRFX-GATE-01`** (a stock QEMU-for-Windows build ships GPU accel disabled, [issue #564](https://gitlab.com/qemu-project/qemu/-/issues/564); acceleration needs a custom QEMU build or crosvm-on-Windows, resolved at M3) — and surfaces each Android app as an **individual native Windows window** using an in-guest **Weston + RDP-RAIL** bridge to `mstsc.exe` — the same windowing model as WSLg. The platform is **fully valid on an x86/x86_64 baseline with no ARM translation**; ARM-only apps are an **optional** layer via **NativeBridge** — an **OPEN RISK**, because upstream AOSP Berberis (Apache-2.0) is a **RISC-V→x86_64** translator, the open ARM64 path ([Digitalis](https://github.com/DigitalisX64/digitalis)) is young, and Google's ARM64 `libndk_translation` is proprietary and user-supplied.

This rebuilds the WSA architecture on a VMM **we control**, so it can't be killed by a platform deprecation.

## Why a VM (not a container)

The closest Linux prior art, [droidloom](research/_clones/droidloom), is a shared-kernel container that requires a **native DRM render node** and **forbids gfxstream/virgl** — impossible to satisfy on a Windows VM or WSL2's `/dev/dxg`. Every viable Windows precedent (WSA, Google Play Games, the AOSP emulator) is a **VM with gfxstream**. So EmberbirdOS is a VM; droidloom is retained as a **design reference** only — we independently reimplement its design, copy none of its GPL-3 source (it's GPL-3; we stay Apache-2.0). Full reasoning: [`PLAN.md` §4](PLAN.md#4-architecture-decision-why-a-vm-not-a-wsl2-container) and [`docs/RESEARCH-SYNTHESIS.md`](docs/RESEARCH-SYNTHESIS.md).

## Documents

| Doc | Contents |
|---|---|
| **[PLAN.md](PLAN.md)** | The master plan: governance & milestone gate spine, architecture decision, system design, component design, repo layout, phased roadmap (M0–M8), testing, licensing, risks, open questions, next actions |
| **[docs/M1-RUNTIME-ARCHITECTURE.md](docs/M1-RUNTIME-ARCHITECTURE.md)** | The **M1 gate**: decision ledger, guest base/lineage (Bliss `arcadia-x86`), kernel (Zenith = Linux 6.18), graphics gate `GRFX-GATE-01`, native-bridge posture, GMS boundary, provenance/signing, guest-image gate, `HYPERV-SEC-01`, milestone-spine reconciliation |
| **[docs/M2-GUEST-BOOT-PROOF.md](docs/M2-GUEST-BOOT-PROOF.md)** | The **M2 execution spec**: per-project manifest lock (`arcadia-x86.pinned.xml`), guest artifact acquisition/build, boot via the frozen M0 launcher, and the exact usable-UI evidence to capture — **now in execution** (X1 done; X2–X5 open) with an execution appendix recording observed values |
| [docs/evidence/M2/](docs/evidence/M2/) | The M2 evidence itself: host environment probe, launcher `-Check`/`-DryRun` transcripts, and the **X1 lock-reproducibility proof** (re-derivation is byte-identical to the committed lock) |
| [docs/RESEARCH-SYNTHESIS.md](docs/RESEARCH-SYNTHESIS.md) | Evidence base — four research passes + cloned-repo ground truth, with confidence tags and sources |
| [docs/REPO-MAP.md](docs/REPO-MAP.md) | Keep/drop verdict for every input repo (droidloom, Box64Droid, bhook, libhoudini, android-openssl-build, BlissRoms-x86) |
| [docs/LICENSING.md](docs/LICENSING.md) | Long-form license analysis: GPL-3 independent-reimplementation boundary, QEMU invoke-don't-link, guest-image source availability, proprietary-translator handling |

## Roadmap at a glance

*This table is the **delivery ordering** (what ships, in what order). The review's **governance spine** — M0 Launcher → M1 Runtime Source & Build Architecture → M2 Guest Boot Proof → M3 Graphics Proof → M4 Runtime Integration → M5 Compatibility → M6 Production Runtime — is a **provenance ordering** (prove the source/build/graphics architecture before production). The two are reconciled, and the WSA-parity milestone (below) is preserved, in [`docs/M1-RUNTIME-ARCHITECTURE.md` §11](docs/M1-RUNTIME-ARCHITECTURE.md). The **⛔ governance gate** that sat between M0 and everything below it has been **cleared**: the owner accepted the M1 architecture on `2026-09-24`, so the M2 Guest Boot Proof is now executing. (The `M1`/`M2` rows below are the *feature roadmap's* numbering, distinct from the review spine's gate numbering — see the reconciliation table.)*

| Milestone | Deliverable | Value |
|---|---|---|
| **M0** | QEMU+WHPX boot launcher — **✅ ACCEPTED & frozen** *(this repo)* | Android UI boots on Windows |
| ✅ **Gate** | **M1 Runtime Source & Build Architecture** — [review PASS · **ACCEPTED BY OWNER `2026-09-24`**](docs/M1-RUNTIME-ARCHITECTURE.md) | guest-image/provenance/kernel/graphics/compat/licensing settled before any runtime code |
| ▶ **Gate** | **M2 Guest Boot Proof** — [**in execution**](docs/M2-GUEST-BOOT-PROOF.md): X1 lock complete + verified; X2 artifact build moves to CI | a pinned guest reaching `sys.boot_completed=1` under the frozen launcher |
| **M1** | virtio-net + ADB + `emberbirdctl` | install/launch apps from the host |
| **M2** | Single-window H.264 stream | **First shippable product** — an app in a Windows window |
| **M3** | gfxstream GPU acceleration *(gated by `GRFX-GATE-01`)* | GPU-accelerated rendering |
| **M4** | In-guest freeform windowing | multiple resizable app windows |
| **M5** | Per-app windows via RDP-RAIL | **WSA parity** — apps as native Windows windows |
| **M6** | Host integration + installer | clipboard, file share, audio, toasts, MSIX |
| **M7** | Berberis ARM app support *(optional layer — OPEN RISK)* | run ARM64-only apps |
| **M8** | crosvm cross-domain v2 | zero-copy performance path |

## Quick start (M0)

Requires Windows 11 with the Windows Hypervisor Platform, [QEMU for Windows](https://qemu.weilnetz.de/w64/), and a BlissOS `arcadia-x86` image.

```powershell
# Verify host prerequisites (WHPX, QEMU, OVMF, WSL2 coexistence) — no VM started
.\tools\qemu\launch-emberbird.ps1 -Check

# Boot a BlissOS image
.\tools\qemu\launch-emberbird.ps1 -Image C:\path\to\bliss_arcadia-x86.iso
```

See [`tools/qemu/README.md`](tools/qemu/README.md) for full options and prerequisite setup.

> **Note on anti-cheat (`HYPERV-SEC-01`, OPEN HOST COMPATIBILITY):** enabling WHPX makes Windows run atop the Microsoft hypervisor, which some kernel-level anti-cheat systems (Vanguard/EAC/BE strict) may block. `bcdedit /set hypervisorlaunchtype off` (reboot) is an **operator-level** choice — EmberbirdOS **never** invokes it silently, and it has a system-wide cost (disables WSL2/Hyper-V/WSA-class features). See [`PLAN.md` §11 R1](PLAN.md#11-risks--mitigations) and [`docs/M1-RUNTIME-ARCHITECTURE.md` §10](docs/M1-RUNTIME-ARCHITECTURE.md).

## License

Proposed **Apache-2.0** for all EmberbirdOS source. Third-party components retain their own licenses; proprietary ARM translators (libhoudini/libndk) are never bundled and are user-supplied at runtime. See [`docs/LICENSING.md`](docs/LICENSING.md).
