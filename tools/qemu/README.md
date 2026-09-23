# EmberbirdOS — M0 QEMU launcher

`launch-emberbird.ps1` is the milestone **M0** artifact: it boots an Android-x86_64 guest (BlissOS `arcadia-x86`, or any Android-x86_64 image) on Windows 11 under **QEMU + WHPX**, and verifies the host is ready. It starts no VM in `-Check` mode and modifies no guest.

See [`../../PLAN.md` §8 (M0)](../../PLAN.md#8-phased-roadmap--milestones) for how this fits the roadmap.

## Prerequisites

1. **Windows Hypervisor Platform (WHPX)** — enable once (elevated PowerShell), then reboot:
   ```powershell
   DISM /online /Enable-Feature /FeatureName:HypervisorPlatform /All
   # (also ensure "Virtual Machine Platform" is on)
   ```
   WHPX is a client of the same Microsoft hypervisor as Hyper-V/WSL2, so it **coexists** with an existing WSL2 install.

2. **QEMU for Windows** — install from <https://qemu.weilnetz.de/w64/> (bundles `qemu-system-x86_64.exe`, `qemu-img.exe`, and OVMF firmware). If it isn't on `PATH`, pass `-QemuPath "C:\Program Files\qemu"`.

3. **OVMF UEFI firmware** — ships with QEMU (`edk2-x86_64-code.fd` / `edk2-i386-vars.fd`, or `OVMF_CODE.fd` / `OVMF_VARS.fd`). Auto-discovered next to QEMU; override with `-OvmfCode` / `-OvmfVars`.

4. **A guest image** — a BlissOS `arcadia-x86` `.iso` (or any Android-x86_64 `.iso`/`.img`/`.raw`).

## Usage

```powershell
# 1) Verify the host is ready (no VM is started)
.\launch-emberbird.ps1 -Check

# 2) Boot an image
.\launch-emberbird.ps1 -Image C:\images\bliss_arcadia-x86.iso

# 3) Tune resources / preview the exact QEMU command without launching
.\launch-emberbird.ps1 -Image C:\images\bliss.iso -Cores 6 -Memory 8G -DryRun
```

Once booted, connect ADB from the host:
```powershell
adb connect 127.0.0.1:58526
```

## Parameters

| Parameter | Default | Meaning |
|---|---|---|
| `-Image <path>` | — | Guest image (`.iso` boots from CD; `.img`/`.raw`/`.qcow2` attaches as a disk). |
| `-Check` | — | Print a host readiness report and exit. Starts no VM. |
| `-Cores <n>` | `4` | Guest vCPUs (1–64). |
| `-Memory <size>` | `4G` | Guest RAM, e.g. `4G` or `4096M`. |
| `-Cpu <model>` | `max` | QEMU `-cpu` model (WHPX-friendly). |
| `-DataDisk <path>` | `..\..\image\out\userdata.qcow2` | Persistent userdata disk (auto-created on first boot). |
| `-DataDiskSizeGB <n>` | `8` | Size of a freshly created userdata disk. |
| `-QemuPath <dir>` | auto | Directory containing `qemu-system-x86_64.exe`. |
| `-OvmfCode` / `-OvmfVars` | auto | UEFI firmware code / writable NVRAM template. |
| `-AdbPort <port>` | `58526` | Host loopback port forwarded to guest `adbd:5555` (WSA's historic port). |
| `-Gpu <mode>` | `gfxstream` | `gfxstream` (auto-fallback), `virgl`, or `none`. |
| `-Display <mode>` | `gtk` | `gtk`, `sdl`, or `none` (headless + serial monitor). |
| `-NoAccel` | off | Boot with TCG software emulation instead of WHPX — very slow, debugging only. |
| `-DryRun` | off | Print the assembled QEMU command and exit; launch nothing. |

## GPU device selection

The target graphics path is `virtio-gpu-rutabaga` with `gfxstream-vulkan=on` (guest gfxstream ICD → host GPU), matching WSA / Google Play Games. Many stock QEMU-for-Windows builds don't yet ship `virtio-gpu-rutabaga`, so with `-Gpu gfxstream` the launcher **probes `qemu -device help`** and gracefully falls back:

```
virtio-gpu-rutabaga (gfxstream)  →  virtio-vga-gl / virtio-gpu-gl (virgl)  →  virtio-gpu (software)
```

`-Check` prints exactly which of these your QEMU build supports. To get the full gfxstream path you may need a QEMU build with rutabaga/gfxstream enabled (tracked as [`PLAN.md` §12 Q1](../../PLAN.md#12-open-questions-to-resolve-during-build)); virgl/GL is a working interim.

## Anti-cheat note

Enabling WHPX makes Windows itself run atop the Microsoft hypervisor. Some kernel-level anti-cheat (Vanguard, EAC/BE in strict mode) may refuse to launch while a hypervisor is present. To fully disable it for gaming:

```powershell
bcdedit /set hypervisorlaunchtype off   # reboot to apply
bcdedit /set hypervisorlaunchtype auto  # re-enable later (reboot)
```

Disabling the hypervisor also disables WHPX/Hyper-V/WSL2 until re-enabled. See [`PLAN.md` §11 R1](../../PLAN.md#11-risks--mitigations).

## Files this script creates

- `tools/qemu/OVMF_VARS.local.fd` — a per-VM writable copy of the UEFI NVRAM (git-ignored).
- The userdata qcow2 at `-DataDisk` (default under `image/out/`, git-ignored).

Neither is committed; both are safe to delete to reset guest state.

## Exit codes

`0` = success / ready. Non-zero = a blocking prerequisite is missing (`-Check`) or QEMU exited with an error (boot). Details are printed with `[FAIL]` markers.
