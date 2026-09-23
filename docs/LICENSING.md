# EmberbirdOS — Licensing & Distribution Analysis

Authoritative long-form license analysis behind [`PLAN.md` §10](../PLAN.md#10-licensing--distribution). This governs what code we may reuse, what obligations attach, and how we may ship. **Not legal advice** — an engineering-grade analysis to keep the project clean; a lawyer should review before public distribution.

## 1. The one rule that shapes the architecture

> **Reusing GPL-3.0 code (droidloom) in our combined work relicenses the *entire* combined work under GPL-3.0-or-later.**

We want EmberbirdOS to be **permissively licensed (Apache-2.0 proposed)** so it can be embedded, forked, and shipped freely. Therefore:

- **droidloom is a design reference only.** We read it for architecture, protocol shape, and threat model, then write an **independent reimplementation informed by that design** — not a formal clean-room. (A clean-room in the legal sense uses a *separate* implementation team that never sees droidloom's source; here the same engineers consult it, so we do not claim that stronger process.) Permitted reuse is scoped to **non-copyrightable functional elements only** — architecture, component decomposition, interfaces, wire-protocol shapes, and the threat model (17 U.S.C. §102(b) excludes ideas, methods, and systems from copyright). droidloom's source — its structure, sequence, organization, and expression — is never reproduced, and we keep a written record of what was consulted. No file, function, or verbatim structure is copied.
- The independent-reimplementation boundary is enforced in the repo layout ([`PLAN.md` §7](../PLAN.md#7-the-emberbirdos-repository-layout)): `host/` and `guest/` are original work. If any droidloom source is ever imported, it is **quarantined** into a clearly-marked GPL-3 module and a deliberate relicense decision is made — never by accident.

## 2. Per-component obligations

| Component | License | Linkage to our code | Obligation | Net effect |
|---|---|---|---|---|
| **Our host + guest source** | **Apache-2.0** (proposed) | — | State changes; keep NOTICE | Permissive core |
| **droidloom** | GPL-3.0-or-later | **None** (design reference) | Copyleft *if* code reused | Avoided via independent reimplementation |
| **AOSP platform** (incl. `libnativebridge`) | Apache-2.0 | Guest platform; our HAL/adapters link/run against it | Attribution + NOTICE | Compatible |
| **Berberis** | Apache-2.0 | Translator via NativeBridge (in guest); upstream targets riscv64→x86_64, ARM path via a non-upstream fork | Attribution + NOTICE | Compatible |
| **bytehook (bhook)** | MIT | Guest-side shim lib | Attribution | Compatible |
| **FreeRDP** | Apache-2.0 (predominant) + LGPL-2.1-or-later / OFL-1.1 (bundled fonts) / HPND components | In-guest RDP-RAIL server | Attribution + NOTICE; **LGPL-2.1 portions add source-availability/relink obligations** — audit per-file for any distributed built image (the §6 THIRD_PARTY manifest covers this) | Compatible |
| **gfxstream / `gfxstream_backend`** | Apache-2.0 | Guest ICD + host backend | Attribution + NOTICE | Compatible |
| **ANGLE** | BSD-3 | Host GL-on-D3D12 | Attribution | Compatible |
| **SwiftShader** | Apache-2.0 | Software GL/Vulkan fallback | Attribution + NOTICE | Compatible |
| **Mesa** (incl. the `vulkan-gfxstream` guest ICD) | MIT + BSD-3 + SGI-B | Guest userspace GL/Vulkan | Attribution | Compatible (in guest image) |
| **BoringSSL / OpenSSL 3.x** | Apache-2.0 | Crypto | Attribution + NOTICE | Compatible |
| **crosvm** | BSD-3 | v2 VMM | Attribution | Compatible |
| **QEMU** | GPL-2.0 | **Invoked as an external process over its CLI — not linked** | GPL-2 applies to QEMU itself; **no linking ⇒ our code is not a derivative** | See §3 |
| **BlissOS `arcadia-x86` image** | Apache-2.0 core + **GPL-2.0 Linux kernel** + assorted per-component | Guest OS image (separate artifact we boot) | Comply per-component; kernel source availability | See §4 |
| **Linux kernel** (in guest image) | GPL-2.0 | Runs in guest; we don't link host code to it | Source availability for any kernel we distribute | See §4 |
| **libhoudini** | Proprietary (Intel) | **Never in source control**; user-supplied runtime drop-in | No redistribution | See §5 |
| **libndk_translation** | Proprietary (Google) | Same | No redistribution | See §5 |

## 3. QEMU (GPL-2.0) — why invoking it is safe

We use QEMU as a **standalone executable launched over its command-line** (`qemu-system-x86_64 -accel whpx ...`), the same way any script invokes a GPL tool. There is **no linking** of QEMU code into our binaries and no shared address space with our proprietary/permissive code. Under the GPL's own "mere aggregation" / separate-program understanding, **invoking a GPL program as a subprocess does not make the caller a derivative work**.

**Distribution stance:** we do **not** bundle a modified QEMU into our own binary. QEMU is either (a) obtained by the user, or (b) shipped as an **unmodified, separately-licensed component** alongside our installer with its own GPL-2 license text and (if we distribute binaries) an offer of corresponding source. If we ever *patch* QEMU, those patches are published under GPL-2 as a separate QEMU fork — they never touch our Apache-2.0 tree.

## 4. The guest image (BlissOS / AOSP + Linux kernel)

The guest OS image is a **separate distributable artifact** from our host code, and is itself a multi-license bundle:

- **AOSP userspace** — Apache-2.0 (attribution/NOTICE).
- **Linux kernel** — **GPL-2.0**: if we distribute a kernel binary, we must make the **corresponding kernel source** (including our config and any patches) available.
- **Per-component** GPL/LGPL/BSD bits pulled by the `arcadia-x86` manifest — each complied with individually.

**Distribution options (decision tracked in [`PLAN.md` §12](../PLAN.md#12-open-questions-to-resolve-during-build) Q8):**
1. **Build-from-manifest** — ship a pinned manifest + build recipe; the user builds the image locally. Cleanest: we distribute no third-party binaries. **Preferred default.**
2. **Signed prebuilt image download** — we host a built image; then we must publish the full corresponding source (kernel + GPL components) and a complete `THIRD_PARTY`/`NOTICE` manifest, and honor the GPL source-offer.

Either way our **host tree stays Apache-2.0** because the guest image is an aggregated, separately-delivered artifact, not linked into host binaries.

## 5. Proprietary translators (libhoudini, libndk_translation)

- **Never** committed, never redistributed, never bundled.
- Delivered only as a **runtime, user-supplied drop-in** (the user extracts them from a source they are licensed to use, e.g. their own WSA/Chrome OS artifacts) into a documented plugin path.
- The product ships with an **in-app notice** stating these are optional proprietary components the user provides, and that the default translation path (**Berberis, Apache-2.0**) is fully open.
- This mirrors how Android-x86/Bliss handle houdini: an opt-in, out-of-band install — not part of the open distribution.

## 6. Attribution & NOTICE generation

- A build step generates a complete **`NOTICE`** + **`THIRD_PARTY.md`** enumerating every bundled component, its license, and its copyright, for both the host distribution and the guest image.
- Apache-2.0 components: retain NOTICE contents. MIT/BSD: retain copyright + license text. **LGPL-2.1-or-later components (e.g. parts of FreeRDP): ship the LGPL text plus the corresponding source (or a written offer) and preserve the ability to relink** — satisfied automatically by the build-from-manifest default (§4). OFL-1.1 bundled fonts: ship the OFL text and keep the reserved font name. GPL components (QEMU, kernel): ship license text + source-availability offer.
- Our own code carries an SPDX header (`Apache-2.0`) per file.

## 7. Summary of the safe posture

1. **Independently reimplement droidloom** → no GPL-3 on our tree.
2. **Invoke, don't link, QEMU** → GPL-2 stays contained to QEMU.
3. **Guest image is a separate, source-available artifact** → kernel/AOSP obligations met without touching host license.
4. **Proprietary translators are user-supplied runtime plugins** → no redistribution liability.
5. **Everything else is MIT/BSD/Apache-2.0** → attribution only.
6. **Our code = Apache-2.0** → permissive, embeddable, clean.

**Action before public release:** legal review of (a) the independent-reimplementation process record for droidloom, (b) the guest-image source-availability mechanism, (c) the proprietary-translator user-supplied model.