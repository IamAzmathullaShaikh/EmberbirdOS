# Crave Windows client: the self-update loop (WinError 183) and its fix

Status: diagnosed and worked around 2026-09-24, on the operator machine that drives the
M2 X2 remote build. Root cause is upstream; the fix here is a shim plus a documented
procedure, not a patch to Crave.

## Symptom

On this machine, a plain `crave <anything>` did not run the command. It appeared to hang,
then eventually failed or fell back:

```
Downloading update https://github.com/accupara/crave/releases/download/0.2-7220/crave-windows-0.2-7220-Windows.zip
Extracting zip: C:\Users\<user>\.crave\bin\0.2-7220
Downloading update https://github.com/accupara/crave/releases/download/0.2-7220/crave-windows-0.2-7220-Windows.zip
Error: Generic failure: [WinError 183] Cannot create a file when that file already exists:
  'C:\Users\BANGER~1\AppData\Local\Temp\crave-0.2-7220.zip_unverified' -> 'C:\Users\BANGER~1\AppData\Local\Temp\crave-0.2-7220.zip'
Deleting the zip file so that it is re-downloaded the next time around: C:\Users\...\Temp\crave-0.2-7220.zip
Download failed continuing to use current crave
crave 0.2-7214-HEAD Windows/x64 (run from C:\Users\<user>\.crave\bin\0.2-7220\crave-windows\crave.exe)
```

Measured cost of one invocation: **107 s and 2 x 28 MB downloaded**, before any of the
requested work began. Interactive work was effectively impossible.

## Root cause

Two upstream defects compound; neither is configurable away.

1. **The released payload reports an older version than its own release tag.** Release
   `0.2-7220` downloads and extracts a binary at
   `~/.crave/bin/0.2-7220/crave-windows/crave.exe` which reports itself as
   **`0.2-7214-HEAD`**. The stub therefore believes the update failed, and the freshly
   extracted payload — invoked *without* the `-n` flag — performs its own update check and
   downloads the same 28 MB release again. That is the visible second `Downloading update`
   in a single invocation, and why the loop can never converge: every layer re-downloads
   the release it came from.

2. **The second download renames onto an existing file.** Crave stages the download at
   `%TEMP%\crave-0.2-7220.zip_unverified` and then renames it to
   `%TEMP%\crave-0.2-7220.zip`. On Windows that rename fails with **WinError 183** when the
   destination already exists (the first layer in the same invocation created it). The
   client deletes the destination zip and continues, but the `_unverified` staging file is
   left behind (25.6 MB observed), which is what keeps the failure reproducible — and note
   the path is resolved through the **8.3 short name** `C:\Users\BANGER~1\...`.

   A failing update also leaves a *nested* payload directory
   (`~/.crave/bin/0.2-7220/crave-windows/0.2-7220/...`), so a subsequent extraction has
   nothing sane to converge on.

## Fix

1. **Use the client's own documented switch.** `-n` / `--noUpdate` is a *global* option (it
   must precede the subcommand) and it skips the entire update path. With it, the same
   commands return immediately. This is already what `AGENTS.md` prescribes for this
   project.

2. **Make it unforgettable: `tools/crave/crave.sh`.** The shim locates the client, deletes
   the stale `%TEMP%\crave-*.zip` / `*.zip_unverified` payloads that make the rename fail,
   and then `exec`s `crave -n "$@"`. Every command in `docs/M2-CRAVE-BUILD.md` goes through
   it.

   ```bash
   bash tools/crave/crave.sh list
   bash tools/crave/crave.sh run --projectID 36 --platform linux16 --no-patch --detached -- "<cmd>"
   bash tools/crave/crave.sh pull eb/image/out/
   ```

3. **Contain the download state.** The failing update writes only under
   `~/.crave/bin/<ver>/` and `%TEMP%`; clearing `~/.crave/bin/<ver>/crave-windows/` and the
   `%TEMP%\crave-*.zip*` files returns the client to a clean, immediately usable state.
   There is no need to reinstall — the installed binary works correctly once the update
   path is skipped.

## What this does not fix

The installed **payload is 0.2-7214-HEAD**, i.e. older than the newest release. With `-n`
that is stable and fully functional for `list`/`run`/`pull`/`getlog`/`admin`; it is
deliberately not "upgraded" by hand, because the upgrade path is the thing that is broken
and a partially applied upgrade is worse than a pinned old client. If Crave ships a release
whose payload version string matches its tag, a plain `crave` invocation should converge on
its own and this shim becomes optional.

## Evidence trail

| Observation | Value |
|---|---|
| Client stub | `~/.crave/bin/crave.exe`, 18419416 bytes, 2026-07-20 |
| Extracted payload | `~/.crave/bin/0.2-7220/crave-windows/crave.exe`, 18404368 bytes |
| Payload self-reported version | `crave 0.2-7214-HEAD Windows/x64` |
| Release the loop re-downloads | `0.2-7220` (`crave-windows-0.2-7220-Windows.zip`, 28645095 bytes) |
| Failure | `WinError 183` renaming `crave-0.2-7220.zip_unverified` -> `crave-0.2-7220.zip` |
| Staging file left behind | `%TEMP%\crave-0.2-7220.zip_unverified`, 28645095 bytes |
| Cost per plain invocation | 107 s, 2 x 28 MB |
| Cost with `-n` | seconds, no download |
