# EmberbirdOS — Research Synthesis

**Purpose:** the evidence base behind [`PLAN.md`](../PLAN.md). Consolidates four deep research passes plus ground-truth from the cloned repos, with a confidence tag and sources on each finding. This is the "show your work" companion to the plan.

**Status:** synthesized 2026-09-23; refreshed 2026-09-23 with the M1-gate research pass (guest lineage/kernel, graphics-on-Windows, ARM-translator landscape, GMS/provenance) — see [`M1-RUNTIME-ARCHITECTURE.md`](M1-RUNTIME-ARCHITECTURE.md). Confidence legend: **[H]** high (confirmed in cloned source or first-party docs), **[M]** medium (multiple secondary sources agree), **[L]** low (single/dated/inferred source — verify during build).

## How this research was done

- **Cloned repos read as ground truth** (`research/_clones/`): `droidloom`, `libhoudini-package`, `android-openssl-build`, `bhook`, `Box64Droid`.
- **BlissRoms-x86** was not cloned (237-repo manifest); read via the public `BlissRoms-x86/manifest` and component docs on the web.
- **Four topic sweeps** (below) combining first-party docs (AOSP, Microsoft WSL/WSLg, QEMU, crosvm, gfxstream) with secondary write-ups.
- **Rule:** cloned-source facts override web claims on conflict; anything only web-sourced and dated is tagged **[L]** and deferred to a build-time check ([`PLAN.md` §12](../PLAN.md#12-open-questions-to-resolve-during-build)).

## 1. ARM → x86_64 translation

- **Posture (decided):** the platform is **fully valid on an x86/x86_64 baseline with no ARM translation** — most Play-Store apps ship x86_64 ABIs, and a translator-free guest is a complete product. ARM64 support is an **optional native-bridge plug-in**, tracked as an **OPEN RISK** (G5/M7), never a launch blocker. Posture recorded in [`M1-RUNTIME-ARCHITECTURE.md`](M1-RUNTIME-ARCHITECTURE.md) §5. **[H]**
- **Berberis** invoked through AOSP **NativeBridge** (`libnativebridge`) is the intended clean path. **But the direction still matters (rechecked 2026):** the **upstream** AOSP `frameworks/libs/binary_translation` (Apache-2.0) remains a **riscv64→x86_64** translator (build target `sdk_phone64_x86_64_riscv64`; runtime `libberberis_riscv64.so`) — **ARM→x86_64 is *not* in the upstream tree**. The non-upstream **"Teto" ARM fork** droidloom once pinned could **not be re-located as a maintained project in 2026** (open risk). **[H]** — droidloom `native-bridge-lock.json` pins Teto at `917021cf3ecd077eb1581146a79d2265011755b8`; AOSP source; 2026 upstream recheck.
- **Digitalis** (`DigitalisX64/digitalis`, first seen 2026-09-13) is the **preferred open ARM64 path** — an open ARM64 backend built on the Apache-2.0 Berberis framework. Young; **to watch**, not yet adopted. **[L]** — single recent source; verify maturity at M5/M7.
- **NativeBridge wiring:** props `ro.dalvik.vm.native.bridge`, `ro.dalvik.vm.isa.arm[64]`, `ro.enable.native.bridge.exec[64]`, `ro.zygote=zygote64_32`; build flag `WITH_NATIVE_BRIDGE`; `binfmt_misc` (`arm64_dyn`/`arm64_exe`) for native ARM ELF exec. Contract is stable regardless of which translator fills the slot. **[H]**
- **`libndk_translation`** (Google, ARM64, from Chrome OS/ARC) — proprietary and **unpublished**; only a **user-supplied** runtime fallback, never bundled. **[M]**
- **libhoudini** (Intel, proprietary) — **DEAD**: x86_64 Android 11 only, extracted from WSA, unmaintained; retained only as a historical worked-example, not a path forward. **[H]** — confirmed in `libhoudini-package` (Gearlock package, houdini paths, Android-11/x86_64 constraint).
- **Box64/Box86/FEX/Box64Droid = x86→ARM (reverse direction)** — irrelevant to running ARM apps on an x86_64 guest. **[H]** — confirmed by reading `Box64Droid` (wraps Box64 to run *x86* binaries *on ARM* Android).

## 2. WSA / WSLg architecture (the model we rebuild)

- **WSA** ran x86_64 AOSP in a **Hyper-V utility VM** via the **Host Compute System** (HCS, `vmcompute.exe`, `HcsCreateComputeSystem`); managed by `WsaService.exe` + `WsaClient.exe`. **[H]**
- Guest images: `system/product/vendor/system_ext` + `initrd.img` + `userdata.vhdx`. Graphics via **gfxstream** (`gfxstream_backend.dll`) over **virtio-gpu**. ADB on `127.0.0.1:58526`. `\Windows` mounted at `/sdcard/Windows`. Start-Menu tiles per app. **[H]**
- Per-app windows via **VAIL/GrfxRedirection** (WSA) — the analog of WSLg's **RAIL**. **[M]**
- **WSA is dead:** deprecated 2024-03-05, support ended 2025-03-05, broken on Win11 24H2/26100+. → We must own the VMM, not depend on HCS/WSA. **[H]**
- **WSLg** is the living, documented reference for the windowing bridge: in-guest **Weston** + **FreeRDP** with **RAIL** (Remote Application Integrated Locally) surfaces each Linux GUI app as an individual Windows window; **WSLGd** supervises; a **WSLDVCPlugin** feeds Start-Menu entries; clipboard/audio plumbed over RDP dynamic virtual channels. **[H]** — first-party `microsoft/wslg`.
- **Takeaway:** WSLg's Weston+RAIL→`mstsc.exe` path is directly adaptable to Android per-task surfaces — this is the M5 mechanism. **[H]**

## 3. BlissRoms-x86 / AOSP-x86 build map

- The single manifest that matters: **`github.com/BlissRoms-x86/manifest`, branch `arcadia-x86`** (Bliss OS 16.x = Android 13). The "237 repos" are its per-component AOSP forks pulled by that manifest — not 237 independent things to study. **[H]**
- **Kernel (corrected 2026):** BlissOS `arcadia-x86` targets the **"Zenith" kernel = Linux 6.18** (`android-generic/kernel-zenith`, a GKI/ACK fork) — **not** the previously-assumed "Crimson ~6.6". binder is provided via **binderfs** (`CONFIG_ANDROID_BINDER_IPC` + `CONFIG_ANDROID_BINDERFS`) + **memfd**; **ashmem is removed**. **[M]** — `android-generic` kernel branch naming; verify the exact SHA at pin time.
- **CPU model constraint:** the guest must run with **`-cpu host`/`max`** under WHPX — a generic QEMU `-cpu` triggers **SIGILL** in BoringSSL's AVX/SHA-NI paths (same failure class Cuttlefish documents). **[M]**
- BlissOS `arcadia-x86` also ships: Mesa/DRM userspace, a **freeform-by-default** patchset + **farmerbb Taskbar**, and **`vulkan-cereal`/gfxstream** for guest GPU. Bliss builds through the **Android-Generic Project (AGP)** overlay/bring-up framework. **[M]**
- **`docs.blissos.org` is stale** relative to the live manifest branches — **trust the live branches over the docs** on conflict, and pin the `arcadia-x86` manifest SHA. **[M]**
- **The Android-x86 project itself is DEAD** (last real release ~2022, Android 9); its grub/ESP boot lineage (`androidboot.hardware`, HAL shims) still *informs* how an x86_64 Android boots under PC firmware/VMM, but **AGP** is the living bring-up framework BlissOS builds through. **[M]**
- **AOSP `aosp_x86_64` GSI is Plan-B, and it is a *bring-up effort, not a drop-in*.** A plain GSI (now Android 16) **does not boot in vanilla QEMU** — it hits signal-6 / FirstStageMount failures and needs a GRUB/ESP or kernel+initrd boot layer, a first-stage ramdisk, an `fstab.<hw>`, `androidboot.hardware`, HAL shims, and `-cpu host`. BlissOS's value is precisely that it already carries this Android-x86/AGP boot layer. **[M]**

## 4. Windows virtualization & hooking

- **QEMU + WHPX** (`-accel whpx`, Windows Hypervisor Platform) boots Android-x86_64 today and **coexists with Hyper-V/WSL2** (all are clients of the one Microsoft root hypervisor). Chosen as the v1 VMM. **[H]**
- **Graphics-on-Windows (plan-changing finding, 2026):** the **stock QEMU-for-Windows** build (weilnetz `w64`) ships with **GL / virgl / Vulkan acceleration disabled** — [QEMU GitLab issue #564](https://gitlab.com/qemu-project/qemu/-/issues/564) states "OpenGL support is disabled" in the official Windows binary, so the GL-accelerated `virtio-gpu` variants are not compiled in and out-of-the-box only **`virtio-gpu-pci` (software)** is available. *(That `virtio-gpu-rutabaga`/`gfxstream` specifically are also absent is the direct corollary — the same build omits the accelerated GPU stack — rather than a separate line-item named in #564.)* Accel therefore requires either **(a) a custom `EmberbirdOS-QEMU-Windows`** that links `rutabaga_gfx_ffi` + `gfxstream_backend`, or **(b) crosvm-on-Windows** (which officially supports a Windows host and is the canonical rutabaga+gfxstream consumer — and may pull the v2 engine *earlier* than planned). This is the formal graphics gate **`GRFX-GATE-01`**, resolved at M3. **[H]** disabled-GL fact / **[H-inferred]** rutabaga-absent corollary — QEMU issue #564 (verified 2026-09-23); weilnetz build inspection.
- **Guest GPU stack:** `vulkan.ranchu` + GLES-emulation is the recommended guest ICD (vs. Mesa `gfxstream_vk`); **not** Venus. **SwiftShader software rendering is the correct baseline** — the launcher degrading to software when no accel device is present is *by design*, not a bug. **[M]**
- **crosvm-on-Windows** (WHPX backend + rutabaga/gfxstream + **cross-domain Wayland proxy**) is the v2 engine — its cross-domain context can bridge guest Wayland to native host surfaces, the zero-copy escape hatch; `GRFX-GATE-01` may promote it into v1. **[M]**
- **HCS/Hyper-V direct** (what WSA used) remains a long-term option but ties us to the platform surface that killed WSA. **[M]**
- **Cuttlefish** is **Linux-host-only** → rejected on Windows. **[H]**
- **gfxstream** is *designed for the VM boundary* (guest ICD → virtio-gpu → host `gfxstream_backend` → ANGLE/D3D12 or Vulkan) — the exact opposite of droidloom's native-render-node requirement, and the same model as WSA / Google Play Games / the AOSP emulator. **[H]**
- **`HYPERV-SEC-01` (OPEN HOST COMPATIBILITY):** with WHPX/Hyper-V enabled, Windows itself runs as a hypervisor guest → **kernel anti-cheat (Vanguard/EAC/BE strict) may block**. `bcdedit /set hypervisorlaunchtype off|auto` (reboot) is an **operator-level** choice the user may make — EmberbirdOS **never** invokes it silently, and documents its system-wide cost (disables WSL2/Hyper-V/WSA-class features). Defeating anti-cheat is out of scope. **[H]** — recorded in [`M1-RUNTIME-ARCHITECTURE.md`](M1-RUNTIME-ARCHITECTURE.md) §10, [`PLAN.md` §11 R1](../PLAN.md#11-risks--mitigations).
- **bhook / bytehook** (MIT, x86_64, API 16–37): PLT/GOT hooking for **guest-side shims / sensor injection / instrumentation only** — *not* the render hot path (that's a real HAL); `shadowhook` covers inline hooks. **[H]** — confirmed in `bhook` source.
- **Crypto:** BoringSSL / OpenSSL 3.x + NDK r23+ Clang. `android-openssl-build` (OpenSSL 1.0.2p / GCC / NDK 15–17) is a **dated worked-example only**, not adopted as-is. **[H]** — confirmed in `android-openssl-build/README.md`.

## 5. droidloom ground truth (design reference, GPL-3.0-or-later)

Read directly from `research/_clones/droidloom`. **[H]** throughout.

- **Not a VM:** one shared-kernel Android **cell** (userspace container). Each Android top-level task = one host logical display = one Wayland `xdg_toplevel`, surfaced by a host compositor ("Denial").
- **Graphics transport:** private Unix **`SOCK_SEQPACKET`** protocol (`DLOM` magic, `protocol/droidloom-host-v1.md`) exchanging **DMA-BUFs** + **linux-drm-syncobj** timelines; zero-copy direct-layer export from SurfaceFlinger with a composition fallback.
- **The disqualifier for reuse-as-deployment:** `droidloom-x86_64-product.json` **requires a native DRM render node + native Mesa** and sets `forbidden_fallbacks: ["gfxstream","virgl","llvmpipe","DRM card node"]`. This is incompatible with any VM/GPU-PV path on Windows (WSL2's `/dev/dxg`+Mesa-d3d12, or gfxstream). Adopting droidloom as-is would mean gutting its zero-copy core.
- **Build:** `cargo run --locked -j 1 -p droidloom-package -- build`; pinned AOSP base + **14 targeted AOSP patches** (`android/aosp-patches/0001..0014`) + custom vendor partition + Rust host; Android 17 / API 37; produces Arch pacman packages. **Not** a full AOSP fork.
- **Threat model** (`docs/threat-model-v1.md`): 10 mandatory Linux-kernel controls (user/PID/mount/IPC/UTS/net/cgroup namespaces, private binderfs, ashmem/memfd, cgroup v2, veth); explicitly **"NOT VM-equivalent"** isolation.
- **Why it's still the primary design reference:** its component decomposition (runtime/graphics/android/packaging), per-app-window transport, HWC+gralloc→Wayland bridge, and threat model are the best existing map of this exact problem — we mirror the *design*, write our own *code* (independent reimplementation, no droidloom source copied), and swap its native-DRM transport for the VM-appropriate gfxstream + RDP-RAIL path.

## 6. Google Mobile Services, microG & Play Integrity

- **GMS-free by default** — the guest ships with **no** Google Mobile Services; GApps, if wanted, are **user-supplied**. This is the clean-licensing, clean-provenance baseline. **[H]** — decided in [`M1-RUNTIME-ARCHITECTURE.md`](M1-RUNTIME-ARCHITECTURE.md) §6.
- **microG is opt-in** and needs a **current signature-spoofing patch** — Google **changed the mechanism in Nov 2024**, so the legacy toolchain (**NanoDroid / Tingle / Haystack**) is **dead**; a maintained sig-spoof patch against the guest ROM is required. **[M]** — open item, verify the working patch at integration time.
- **Play Integrity `DEVICE`/`STRONG` is structurally impossible in a VM** — no TEE/StrongBox, and Google has required a **hardware-backed key since May 2025**. Only `BASIC` (soft) can ever pass, and even that is fragile. This is a **documented compatibility gap**, not a bug to fix. **[H]**

## 7. Provenance, reproducible build & signing

- **SBOM & supply chain:** AOSP emits **SPDX SBOMs natively** (`m sbom`); target **SLSA L2 → L3**, with **cosign/Sigstore** signing and **in-toto** attestations over the build. **[M]** — first-party AOSP + SLSA/Sigstore docs.
- **Reproducibility:** AOSP is **deterministic-ish but *not* bit-for-bit**. Pinning the manifest SHAs + toolchain + `SOURCE_DATE_EPOCH`/`BUILD_DATETIME` gets to **~99%** (the AXP.OS result). Treat exact reproducibility as a goal, not a guarantee. **[M]**
- **Image signing & OTA:** **AVB/vbmeta** with **offline/HSM keys**, **A/B** slots, and an **avbroot/Custota**-style OTA path. In a VM without a hardware root of trust, **AVB is integrity-*advisory*** (tamper-evidence for our build chain), not a hardware-enforced boot guarantee. **[M]** — recorded in [`M1-RUNTIME-ARCHITECTURE.md`](M1-RUNTIME-ARCHITECTURE.md) §§7–8.
- **Guest-image strategy (gate RESOLVED, both/and):** **build-from-pinned-manifest** is the default and the provenance anchor; a **signed prebuilt** derived from that same build is the usability layer (and satisfies per-component GPL/LGPL source-availability obligations as a build step). Not "vs." — both. **[H]** — [`M1-RUNTIME-ARCHITECTURE.md`](M1-RUNTIME-ARCHITECTURE.md) §9, [`LICENSING.md`](LICENSING.md) §4.

## 8. Net conclusions feeding the plan

1. **VM, not container** — every viable Windows precedent (WSA, Play Games, AOSP emulator) is a VM with gfxstream; droidloom's container needs Linux-kernel primitives Windows lacks. → **Track B**.
2. **Own the VMM** — WSA died with its HCS dependency; QEMU-WHPX (→crosvm) keeps us off the fragile platform surface.
3. **WSLg is the windowing blueprint** — Weston+RAIL→`mstsc.exe` maps cleanly onto Android per-task surfaces.
4. **x86_64 baseline is the product; ARM is optional** — a translator-free guest is complete and shippable; ARM64 is an opt-in native-bridge plug-in (Digitalis to watch, `libndk` user-supplied) and an **OPEN RISK**, never a blocker.
5. **Independently reimplement droidloom** — design yes, code no, to stay off GPL-3.
6. **gfxstream is the right graphics model** — it's built for exactly the VM boundary droidloom forbids — **but stock QEMU-for-Windows ships it disabled** (issue #564), so accel is gated (`GRFX-GATE-01`) behind a custom QEMU build or crosvm-on-Windows; **SwiftShader software is the correct baseline** meanwhile.
7. **BlissOS `arcadia-x86` for its boot layer** — Zenith/6.18 kernel, AGP bring-up, freeform patchset; AOSP GSI stays Plan-B as a *boot-layer build effort*, not a drop-in. Pin the manifest SHA; trust live branches over stale docs.
8. **Clean provenance, honest compat boundaries** — GMS-free default, SBOM+SLSA+signed build; Play Integrity `DEVICE`/`STRONG` is structurally out of reach in a VM and documented as such.

All of the above is reflected in [`PLAN.md`](../PLAN.md); per-repo keep/drop verdicts are in [`REPO-MAP.md`](REPO-MAP.md); license detail in [`LICENSING.md`](LICENSING.md).

## 9. Durable source ledger (evidence references)

Per the M1 review's evidence-durability requirement, every load-bearing **[H]/[M]** claim carries a durable reference below. **Status legend:** 🟢 *verified live 2026-09-23* · 🔵 *first-party doc / canonical repo* · 🟣 *in-repo cloned source* (`research/_clones/`) · 🟠 *secondary/dated — verify at build*. Confidence tags ([H]/[M]/[L]) are unchanged from the sections above; this table adds the *locator* and *verification state*, not a new verdict. The full claim↔confidence map is the [`M1-RUNTIME-ARCHITECTURE.md` evidence appendix](M1-RUNTIME-ARCHITECTURE.md#evidence-appendix) (E1–E17); this ledger records where each is anchored.

| Load-bearing claim | Durable reference | Status |
|---|---|---|
| Guest-base pin: `arcadia-x86` = `98a0a79…` (Bliss 16.x/A13); branch head == default HEAD; committed 2026-04-12 | `git ls-remote https://github.com/BlissRoms-x86/manifest.git`; GitHub commits API `/repos/BlissRoms-x86/manifest/commits/98a0a79…`; recorded in [`image/manifest/arcadia-x86.pin.json`](../image/manifest/arcadia-x86.pin.json) | 🟢 verified live 2026-09-23 |
| Graphics: stock QEMU-for-Windows ships GL/accel disabled → software-only `virtio-gpu-pci` (rutabaga/gfxstream absent = corollary) | [QEMU GitLab issue #564](https://gitlab.com/qemu-project/qemu/-/issues/564) | 🟢 verified live 2026-09-23 (scope confirmed: issue names GL/virgl/Vulkan; rutabaga/gfxstream absence inferred) |
| ARM: Digitalis = open ARM64 backend on Apache-2.0 Berberis; young/unproven | [`DigitalisX64/digitalis`](https://github.com/DigitalisX64/digitalis) + digitalisx64.github.io | 🟢 existence verified 2026-09-23 (maturity deferred to M5/M7) |
| ARM: upstream Berberis is riscv64→x86_64 only; ARM not upstream | AOSP `frameworks/libs/binary_translation` (build target `sdk_phone64_x86_64_riscv64`, `libberberis_riscv64.so`) | 🔵 first-party (AOSP tree) |
| droidloom forbids gfxstream/virgl/llvmpipe; requires a native DRM render node | `research/_clones/droidloom` product json (`forbidden_fallbacks`) | 🟣 in-repo clone |
| gfxstream is the VM-boundary graphics model (WSA / Play Games / AOSP emulator) | AOSP gfxstream docs; WSA architecture write-ups | 🔵 first-party / 🟠 secondary |
| Kernel = Zenith / Linux 6.18 (GKI/ACK); binderfs + memfd; ashmem removed | `android-generic/kernel-zenith` branch; AOSP binderfs docs | 🔵 first-party (exact SHA pinned at M2) |
| WSA architecture (HCS utility VM, gfxstream, ADB `:58526`); WSA EOL 2025-03-05 | Microsoft WSA docs / EOL notice; `microsoft/wslg` (RAIL blueprint) | 🔵 first-party |
| microG needs a current sig-spoof patch (Google changed the mechanism Nov 2024; legacy patchers dead) | LineageOS-for-microG / CalyxOS patch lineage | 🟠 secondary — verify a working patch at M4/M5 |
| Play Integrity DEVICE/STRONG needs a HW-backed key (since May 2025) → impossible in a VM | Google Play Integrity API docs (developer.android.com) | 🔵 first-party |
| AOSP not bit-for-bit; ~99% with pinned manifest+toolchain+`SOURCE_DATE_EPOCH` | AXP.OS reproducibility reports; AOSP `m sbom` docs | 🟠 secondary — confirm % at M6 |
| bhook/bytehook (MIT); Box64Droid (reverse x86-on-ARM); android-openssl-build (dated); libhoudini (dead, A11) | `research/_clones/{bhook,Box64Droid,android-openssl-build,libhoudini-package}` | 🟣 in-repo clone |

**Live-verification note (this M1 closure pass):** the three highest-stakes claims were re-checked against their primary sources on 2026-09-23 — the guest-base pin (drives M2), the graphics-disabled finding (drives M3 / `GRFX-GATE-01`), and Digitalis (drives M7 / ARM). The remaining references point at canonical first-party docs, cloned-repo ground truth, or are honestly flagged 🟠 for build-time re-verification; **none is upgraded in confidence by this pass.**
