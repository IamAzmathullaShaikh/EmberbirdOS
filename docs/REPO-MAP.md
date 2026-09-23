# EmberbirdOS — Repository Map

Per-input verdict for every repo the owner named, plus the key external references. This is the "what we keep, what we drop, and why" ledger. Companion to [`PLAN.md`](../PLAN.md) and [`RESEARCH-SYNTHESIS.md`](RESEARCH-SYNTHESIS.md).

**Verdict key:** ✅ **Adopt** (used in the build) · 📐 **Reference** (design/knowledge only, no code) · 🔌 **Runtime-optional** (user-supplied at runtime, never in source control) · ❌ **Drop** (not relevant to our direction).

## Named inputs

| Repo / input | License | What it is | Relevance to EmberbirdOS | Verdict |
|---|---|---|---|---|
| **droidloom** (`denialwm/droidloom`) | GPL-3.0-or-later | Shared-kernel Android **cell** on Linux; each task → a Wayland `xdg_toplevel` via a host compositor; zero-copy DMA-BUF/drm-syncobj transport; Berberis "Teto"; 14 AOSP patches | Closest existing implementation of our *goal* on Linux. Its design (component split, per-app window transport, HWC/gralloc→Wayland bridge, threat model) is our primary map. **But** it requires a native DRM render node and forbids gfxstream/virgl/llvmpipe → unusable as-is on a Windows VM, and GPL-3 would relicense our whole work. | 📐 **Reference** (independent reimpl; no code import) |
| **Box64Droid** (`Rprop/Box64Droid`) | — | Automation to run **x86/x86_64 binaries on ARM Android** via Box64/Box86 | **Wrong direction.** We run ARM apps on an x86_64 guest; this is the reverse. No overlap. | ❌ **Drop** |
| **bhook / bytehook** (`bytedance/bhook`) | MIT | Android **PLT/GOT hook** library (+ `shadowhook` inline), x86_64, API 16–37 | Guest-side shims, sensor/telephony injection, instrumentation, compat quirks — *not* the render hot path (that's a real HAL). Clean MIT. | ✅ **Adopt** (guest tooling) |
| **libhoudini-package** (`.../libhoudini`) | Proprietary (Intel) | Gearlock package delivering **libhoudini** ARM→x86_64 translator, extracted from WSA; **x86_64 Android 11 only** | Optional fallback translator when Berberis can't run an app. Not redistributable → never committed; user supplies at runtime. | 🔌 **Runtime-optional** |
| **android-openssl-build** (`.../android-openssl-build`) | (script repo) | Cross-compiles **OpenSSL 1.0.2p** with GCC / NDK 15–17 for Android | Dated worked-example of NDK crypto cross-compilation. We target **BoringSSL / OpenSSL 3.x + NDK r23+ Clang** instead. | 📐 **Reference** (example only) |
| **BlissRoms-x86** (237-repo manifest) | AOSP Apache-2.0 + GPL-2 kernel + assorted | Android-x86 distro. The one repo that matters: **`BlissRoms-x86/manifest` branch `arcadia-x86`** (Android 13), pinned at revision `98a0a79` ([`image/manifest/arcadia-x86.pin.json`](../image/manifest/arcadia-x86.pin.json)); the 237 repos are its per-component AOSP forks | Our **v1 guest image**: android-generic **"Zenith" kernel = Linux 6.18** (GKI/ACK fork), Mesa/DRM, freeform-by-default + Taskbar, `vulkan-cereal`/gfxstream. Pin the manifest; keep AOSP GSI as the clean-rebase Plan-B. | ✅ **Adopt** (guest image v1) |

## Hashtag / topic inputs (research themes, not repos)

| Input | Treatment |
|---|---|
| **#WSA** | The architecture we rebuild (Hyper-V/HCS VM + gfxstream + VAIL windows). Studied as the model; not usable (dead, closed). → [`RESEARCH-SYNTHESIS.md` §2](RESEARCH-SYNTHESIS.md#2-wsa--wslg-architecture-the-model-we-rebuild) |
| **#Bluestacks** | Commercial Android-on-PC emulator (closed). Confirms the VM+gfxstream+windowing model is the industry-standard approach. Reference only. |
| **#AOSP** | The platform base (Apache-2.0); source of `libnativebridge`, freeform APIs, HAL contracts, GSI. ✅ Adopt. |
| **#AOSPinPC / #runningandroidinpc** | Android-x86 lineage knowledge (boot on PC firmware/VMM, HAL shims). 📐 Reference. |

## Key external references adopted into the build (not owner-named, surfaced by research)

| Component | License | Role | Verdict |
|---|---|---|---|
| **QEMU** (+ WHPX accel, `virtio-gpu-rutabaga`) | GPL-2.0 | v1 VMM; invoked over CLI (not linked) so it doesn't relicense our code | ✅ **Adopt** (external tool) |
| **crosvm** (Windows, rutabaga, cross-domain) | BSD-3 | v2 VMM + zero-copy Wayland bridge | ✅ **Adopt** (v2) |
| **gfxstream** + **`gfxstream_backend`** | Apache-2.0 | Guest ICD ↔ host GPU backend across the VM boundary | ✅ **Adopt** |
| **ANGLE / SwiftShader** | BSD/Apache | Host GL-on-D3D12 / **software rendering — the CI-ready baseline** (also the GPU-less fallback) | ✅ **Adopt** |
| **Mesa** (`vulkan-gfxstream` gfxstream ICD) | MIT + BSD-3 + SGI-B | Guest userspace GL/Vulkan + gfxstream ICD | ✅ **Adopt** (in guest image) |
| **Berberis** (upstream `frameworks/libs/binary_translation`; ARM backend = open risk) | Apache-2.0 | Upstream AOSP Berberis is a **riscv64→x86_64** translator; **ARM→x86_64 is not in the upstream tree**. The "Teto" ARM fork droidloom once pinned (`917021cf…`) **could not be re-located as maintained in 2026**; the preferred open ARM64 backend is now **Digitalis** ([`DigitalisX64/digitalis`](https://github.com/DigitalisX64/digitalis)), young/unproven — to watch. ARM is wired via NativeBridge as an **optional layer** and tracked as an **OPEN RISK** (G5/M7). | ✅ framework (Apache-2.0) · 🔌 ARM backend **optional, OPEN RISK** (watch Digitalis) |
| **libnativebridge** (AOSP) | Apache-2.0 | Translator plug-in contract + props/`binfmt_misc` | ✅ **Adopt** |
| **libndk_translation** | Proprietary (Google) | Secondary proprietary fallback translator | 🔌 **Runtime-optional** |
| **microsoft/wslg** (Weston + FreeRDP RAIL, WSLGd, DVC plugin) | MIT | Design blueprint for the per-app windowing bridge (M5) | 📐 **Reference** (adapt, independent reimpl) |
| **FreeRDP** | Apache-2.0 (predominant) + LGPL-2.1-or-later / OFL-1.1 / HPND | RDP-RAIL server in-guest → `mstsc.exe` on host | ✅ **Adopt** (audit per-file license on any distributed image) |
| **BoringSSL / OpenSSL 3.x** | Apache-2.0 | Crypto | ✅ **Adopt** |

## One-line rationale for the headline calls

- **droidloom → reference, not code:** GPL-3 contamination + native-DRM-render-node requirement that a Windows VM can't satisfy.
- **Box64Droid → dropped:** reverse translation direction (x86-on-ARM).
- **BlissOS → adopted as v1 guest:** it already carries the kernel + Mesa/DRM + freeform + gfxstream we need; AOSP GSI is the clean-rebase exit.
- **QEMU-WHPX → v1 VMM:** boots Android-x86_64 today, coexists with WSL2, carries the `virtio-gpu-rutabaga`/gfxstream device model upstream (host accel gated by `GRFX-GATE-01`; SwiftShader software baseline until then); crosvm is the v2 upgrade.
- **Berberis → framework adopted; ARM backend is the OPEN part:** the Apache-2.0 Berberis framework + NativeBridge contract are clean and adopted, but a maintained *ARM64* backend is unsettled (upstream is riscv64-only; the Teto fork is unlocatable in 2026; Digitalis is open but young). ARM stays an optional layer / OPEN RISK; proprietary translators stay runtime-optional.