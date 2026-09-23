#Requires -Version 5.1
<#
.SYNOPSIS
    Self-contained verification suite for launch-emberbird.ps1 (EmberbirdOS M0).

.DESCRIPTION
    Exercises the launcher with NO real QEMU / OVMF present. It compiles a tiny
    console stub that impersonates qemu-system-x86_64.exe (answering --version and,
    driven by the STUB_DEVICES env var, "-device help"), stages matched and
    mismatched OVMF firmware sets in throwaway directories, and drives the
    launcher's -Check and -DryRun code paths. Without booting anything, it asserts:
      * the launcher parses and is pure ASCII, with no dangling references to
        symbols removed during refactoring;
      * -DryRun is side-effect-free (writes no userdata disk / NVRAM copy);
      * the assembled QEMU command is correct for .qcow2 / .img / .iso guests
        (WHPX accel, NO kernel-irqchip flag, -vga none ordered before virtio-gpu,
        extension-correct format=, ADB hostfwd on 127.0.0.1:58526);
      * OVMF CODE/VARS resolve as a build-matched family PAIR - never a cross-family
        mix, and the combined OVMF.fd is never used as a split-pflash member;
      * GPU device auto-selection honours the documented fallback order
        rutabaga(gfxstream) > virtio-vga-gl > virtio-gpu-gl > software.

    Exits 0 when every assertion passes, 1 otherwise (CI-friendly). Leaves nothing
    behind outside its own temp workspace and never writes into the repo.

    NOTE: the command-assembly and GPU cases require a host where a hypervisor is
    present (WHPX's precondition) - the same environment the launcher targets.

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\qemu\tests\Test-Launcher.ps1
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$launcher = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\launch-emberbird.ps1')).Path
$qemuDir  = Split-Path -Parent $launcher
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $qemuDir '..\..')).Path
$work     = Join-Path ([System.IO.Path]::GetTempPath()) ("emberbird-launcher-tests-" + $PID)
if (Test-Path -LiteralPath $work) { Remove-Item -LiteralPath $work -Recurse -Force }
New-Item -ItemType Directory -Path $work -Force | Out-Null

$script:Pass = 0
$script:Fail = 0
function Assert([string] $Label, [bool] $Ok, [string] $Detail = '') {
    if ($Ok) { $script:Pass++; $tag = 'PASS' } else { $script:Fail++; $tag = 'FAIL' }
    $color = if ($Ok) { 'Green' } else { 'Red' }
    Write-Host ('  {0} {1}{2}' -f $tag, $Label, $(if ($Detail) { "  ($Detail)" } else { '' })) -ForegroundColor $color
}
function Section([string] $t) { Write-Host ''; Write-Host "== $t ==" -ForegroundColor Cyan }

try {
    # --- compile a real, controllable qemu-system stub --------------------
    # Add-Type writes a genuine console .exe to disk WITHOUT loading it into
    # this session. --version returns a plausible banner (so -Check's version
    # probe succeeds); "-device help" echoes the pipe-delimited STUB_DEVICES
    # env var, which child powershell processes inherit - that is how the GPU
    # fallback cases feed a controlled device list into Select-GpuDevice.
    $stubExe  = Join-Path $work 'qemu-system-x86_64.exe'
    $stubCode = @'
using System;
public class QemuStub {
  public static void Main(string[] args) {
    string j = string.Join(" ", args);
    if (j.Contains("--version")) { Console.WriteLine("QEMU emulator version 9.1.0 (EmberbirdOS-test-stub)"); return; }
    if (j.Contains("-device") && j.Contains("help")) {
      string d = Environment.GetEnvironmentVariable("STUB_DEVICES");
      if (!string.IsNullOrEmpty(d)) { foreach (var x in d.Split('|')) Console.WriteLine(x); }
      return;
    }
  }
}
'@
    Add-Type -OutputType ConsoleApplication -OutputAssembly $stubExe -TypeDefinition $stubCode -WarningAction SilentlyContinue

    # --- helpers ----------------------------------------------------------
    function New-CaseDir([string] $Name, [string[]] $Ovmf) {
        $d = Join-Path $work $Name
        New-Item -ItemType Directory -Path $d -Force | Out-Null
        Copy-Item -LiteralPath $stubExe -Destination (Join-Path $d 'qemu-system-x86_64.exe') -Force
        Set-Content -LiteralPath (Join-Path $d 'qemu-img.exe') -Value '' -Encoding Ascii
        foreach ($f in $Ovmf) { Set-Content -LiteralPath (Join-Path $d $f) -Value 'FW' -Encoding Ascii }
        return $d
    }
    # The launcher exits via `exit` and prints with Write-Host (stream 6), so it
    # is always run as a child process and captured with 2>&1 - never dot-sourced.
    function Invoke-Launcher([string[]] $LauncherArgs) {
        $a = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $launcher) + $LauncherArgs
        return (& powershell @a 2>&1 | Out-String)
    }
    function Get-CmdLine([string] $Out) {
        $line = ($Out -split "`n" | Where-Object { $_ -match 'qemu-system-x86_64\.exe' -and $_ -match '-machine' } | Select-Object -First 1)
        if ($line) { return $line }
        return ($Out -replace "`r?`n", ' ')
    }
    # NB: "${which}:" not "$which:" - a trailing ':' after a bare $var is parsed
    # as a drive/scope qualifier under StrictMode and breaks the regex.
    function Get-Resolved([string] $Out, [string] $Which) {
        foreach ($ln in ($Out -split "`n")) { if ($ln -match "\[OK\]\s+${Which}:\s*(\S.*?)\s*$") { return (Split-Path -Leaf $Matches[1]) } }
        return $null
    }

    # ======================================================================
    Section 'Static analysis'
    $perr = $null; $ptok = $null
    [System.Management.Automation.Language.Parser]::ParseFile($launcher, [ref]$ptok, [ref]$perr) | Out-Null
    Assert 'parses without error' (-not ($perr -and $perr.Count)) $(if ($perr -and $perr.Count) { "$($perr.Count) error(s)" } else { 'AST OK' })

    $srcLines = Get-Content -LiteralPath $launcher
    $na = @(); for ($i = 0; $i -lt $srcLines.Count; $i++) { if ($srcLines[$i] -match '[^\x00-\x7F]') { $na += ($i + 1) } }
    Assert 'is pure ASCII' ($na.Count -eq 0) $(if ($na.Count) { 'non-ASCII at L' + ($na -join ',') } else { '0 non-ASCII bytes' })

    $leftover = Select-String -LiteralPath $launcher -Pattern 'Resolve-OvmfFile|__OVMF_RESOLVE_PAIR__'
    Assert 'no dangling refs to removed symbols' (-not $leftover) $(if ($leftover) { 'at L' + (($leftover | ForEach-Object { $_.LineNumber }) -join ',') } else { 'clean' })

    # ======================================================================
    Section 'DryRun: assembled QEMU command (format matrix)'
    $fmtDir = New-CaseDir 'fmt' @('OVMF_CODE_4M.fd', 'OVMF_VARS_4M.fd')
    $code   = Join-Path $fmtDir 'OVMF_CODE_4M.fd'
    $vars   = Join-Path $fmtDir 'OVMF_VARS_4M.fd'
    foreach ($img in 'guest.qcow2', 'guest.img', 'guest.iso') { Set-Content -LiteralPath (Join-Path $fmtDir $img) -Value 'X' -Encoding Ascii }
    $matrix = @(
        @{ n = 'guest.qcow2'; expect = 'format=qcow2' },
        @{ n = 'guest.img';   expect = 'format=raw'   },
        @{ n = 'guest.iso';   expect = '-cdrom'       }
    )
    foreach ($c in $matrix) {
        $out = Invoke-Launcher @('-Image', (Join-Path $fmtDir $c.n), '-QemuPath', $fmtDir, '-OvmfCode', $code, '-OvmfVars', $vars, '-DryRun')
        $cmd = Get-CmdLine $out
        $vi  = $cmd.IndexOf('-vga'); $gi = $cmd.IndexOf('virtio-gpu')
        $ok  = ($cmd -match 'accel=whpx') -and (-not ($cmd -match 'kernel-irqchip')) -and
               ($vi -ge 0 -and $gi -ge 0 -and $vi -lt $gi) -and
               ($cmd -match [regex]::Escape($c.expect)) -and
               ($cmd -match 'hostfwd=tcp:127\.0\.0\.1:58526-:5555')
        Assert ("command correct for {0}" -f $c.n) $ok "whpx, no-irqchip, vga<gpu, $($c.expect), adb58526"
    }

    # ======================================================================
    Section 'DryRun: no side effects'
    # The qcow2 DryRun above must NOT have created the per-VM NVRAM copy (in the
    # launcher's own dir) nor the userdata disk (image\out) - those belong only
    # to the real boot path.
    $localVars = Join-Path $qemuDir 'OVMF_VARS.local.fd'
    $userData  = Join-Path $repoRoot 'image\out\userdata.qcow2'
    Assert 'no OVMF_VARS.local.fd written' (-not (Test-Path -LiteralPath $localVars)) 'launcher dir clean'
    Assert 'no userdata.qcow2 written'     (-not (Test-Path -LiteralPath $userData))  'image\out clean'

    # ======================================================================
    Section 'OVMF CODE/VARS matched-pair resolution'
    # If the host happens to carry a real OVMF family pair in a standard search
    # dir, the resolver would (correctly) find it, so the negative cases cannot
    # assert "both unresolved". We detect that and fall back to the always-true
    # safety property (combined blob never split; families never crossed).
    $fams = @(
        @('edk2-x86_64-code.fd', 'edk2-i386-vars.fd'),
        @('OVMF_CODE_4M.fd', 'OVMF_VARS_4M.fd'),
        @('OVMF_CODE.fd', 'OVMF_VARS.fd')
    )
    $stdDirs = @("$env:ProgramFiles\qemu\share", "$env:ProgramFiles\qemu", 'C:\msys64\ucrt64\share\qemu', 'C:\msys64\mingw64\share\qemu') | Where-Object { $_ }
    $hostHasPair = $false
    foreach ($d in $stdDirs) { foreach ($f in $fams) { if ((Test-Path -LiteralPath (Join-Path $d $f[0])) -and (Test-Path -LiteralPath (Join-Path $d $f[1]))) { $hostHasPair = $true } } }
    if ($hostHasPair) { Write-Host '  [note] host has real OVMF in a standard dir; negative cases assert the weaker safety property.' -ForegroundColor DarkGray }

    $dPair = New-CaseDir 'ovmf-pair' @('OVMF_CODE_4M.fd', 'OVMF_VARS_4M.fd')
    $oA = Invoke-Launcher @('-Check', '-QemuPath', $dPair)
    Assert 'A none-explicit auto-pairs one family' (((Get-Resolved $oA 'OVMF_CODE') -eq 'OVMF_CODE_4M.fd') -and ((Get-Resolved $oA 'OVMF_VARS') -eq 'OVMF_VARS_4M.fd'))

    $oB = Invoke-Launcher @('-Check', '-QemuPath', $dPair, '-OvmfCode', (Join-Path $dPair 'OVMF_CODE_4M.fd'))
    Assert 'B code-explicit finds vars partner' ((Get-Resolved $oB 'OVMF_VARS') -eq 'OVMF_VARS_4M.fd')

    $oC = Invoke-Launcher @('-Check', '-QemuPath', $dPair, '-OvmfVars', (Join-Path $dPair 'OVMF_VARS_4M.fd'))
    Assert 'C vars-explicit finds code partner' ((Get-Resolved $oC 'OVMF_CODE') -eq 'OVMF_CODE_4M.fd')

    $dCombined = New-CaseDir 'ovmf-combined' @('OVMF.fd')
    $oD = Invoke-Launcher @('-Check', '-QemuPath', $dCombined)
    $cD = Get-Resolved $oD 'OVMF_CODE'; $vD = Get-Resolved $oD 'OVMF_VARS'
    $dOk = ($cD -ne 'OVMF.fd') -and ($vD -ne 'OVMF.fd')
    if (-not $hostHasPair) { $dOk = $dOk -and (-not $cD) -and (-not $vD) }
    Assert 'D combined OVMF.fd never used as a pflash member' $dOk "code=$cD vars=$vD"

    $dCross = New-CaseDir 'ovmf-cross' @('OVMF_CODE_4M.fd', 'edk2-i386-vars.fd')
    $oE = Invoke-Launcher @('-Check', '-QemuPath', $dCross)
    $cE = Get-Resolved $oE 'OVMF_CODE'; $vE = Get-Resolved $oE 'OVMF_VARS'
    $eOk = -not (($cE -eq 'OVMF_CODE_4M.fd') -and ($vE -eq 'edk2-i386-vars.fd'))
    if (-not $hostHasPair) { $eOk = $eOk -and (-not $cE) -and (-not $vE) }
    Assert 'E cross-family pair rejected' $eOk "code=$cE vars=$vE"
    # ======================================================================
    Section 'GPU device auto-selection order'
    # Documented fallback for the gfxstream profile:
    #   rutabaga(gfxstream) > virtio-vga-gl > virtio-gpu-gl-pci > virtio-gpu-pci(sw)
    # STUB_DEVICES controls what "-device help" reports, so each case exercises a
    # different available-device set and we read back what -vga none was paired with.
    $dGpu  = New-CaseDir 'gpu' @('OVMF_CODE_4M.fd', 'OVMF_VARS_4M.fd')
    Set-Content -LiteralPath (Join-Path $dGpu 'guest.img') -Value 'X' -Encoding Ascii
    $gCode = Join-Path $dGpu 'OVMF_CODE_4M.fd'
    $gVars = Join-Path $dGpu 'OVMF_VARS_4M.fd'
    function Get-GpuPick([string] $Devices) {
        $env:STUB_DEVICES = $Devices
        try {
            $out = Invoke-Launcher @('-Image', (Join-Path $dGpu 'guest.img'), '-QemuPath', $dGpu, '-OvmfCode', $gCode, '-OvmfVars', $gVars, '-DryRun')
        } finally { $env:STUB_DEVICES = $null }
        $cmd = Get-CmdLine $out
        if ($cmd -match '-vga none -device ("[^"]+"|\S+)') { return ($Matches[1].Trim('"')) }
        return '(none)'
    }
    $g1 = Get-GpuPick 'virtio-gpu-rutabaga|virtio-vga-gl|virtio-gpu-gl-pci|virtio-gpu-pci'
    Assert 'all present -> virtio-gpu-rutabaga (gfxstream)' ($g1 -like 'virtio-gpu-rutabaga*') "picked=$g1"
    $g2 = Get-GpuPick 'virtio-vga-gl|virtio-gpu-gl-pci|virtio-gpu-pci'
    Assert 'no rutabaga -> virtio-vga-gl (before gpu-gl)' ($g2 -eq 'virtio-vga-gl') "picked=$g2"
    $g3 = Get-GpuPick 'virtio-gpu-gl-pci|virtio-gpu-pci'
    Assert 'only gpu-gl -> virtio-gpu-gl-pci' ($g3 -eq 'virtio-gpu-gl-pci') "picked=$g3"
    $g4 = Get-GpuPick 'virtio-gpu-pci'
    Assert 'none accelerated -> software virtio-gpu-pci' ($g4 -eq 'virtio-gpu-pci') "picked=$g4"
}
finally {
    if (Test-Path -LiteralPath $work) { Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue }
}

Section 'Summary'
$sumColor = if ($script:Fail -eq 0) { 'Green' } else { 'Red' }
Write-Host ("  {0} passed, {1} failed" -f $script:Pass, $script:Fail) -ForegroundColor $sumColor
if ($script:Fail -gt 0) { exit 1 }
exit 0




