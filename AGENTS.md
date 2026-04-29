# AGENTS.md

This repository contains a native tracker playback DLL plus helper projects. Future agents should treat it as a Windows-first Visual Studio codebase with an installer-oriented integration target.

## Primary Goal

The most important maintained outcome is:

- `TrackerPlayback.dll` can be consumed from Inno Setup through `stdcall` exports.

The relevant installer-facing exports are declared in:

- [TrackerPlayback/TrackerPlayback.h](TrackerPlayback\TrackerPlayback.h)
- [InnoSetupTrackerPlayback.iss.inc](InnoSetupTrackerPlayback.iss.inc)

The `stdcall` wrapper implementation lives in:

- [TrackerPlayback/TrackerPlaybackInno.c](TrackerPlayback\TrackerPlaybackInno.c)

## Project Layout

- `TrackerPlayback/`
  Native DLL project. This is the main deliverable.
- `TrackerPlayer/`
  Small Win32 executable that uses the DLL.
- `TrackerPlaybackTest/`
  WPF test harness for the DLL.
- `TrackerPlayback/ThirdParty/openmpt/`
  Bundled OpenMPT dependency tree.
- `scripts/Build-InnoDll.cmd`
  Preferred build entry point for generating the Inno-ready package.
- `scripts/Build-InnoDll.ps1`
  Secondary PowerShell implementation kept for reference/CI logic.

## Build Rules

When asked to build the installer-ready DLL, prefer this command:

```bat
.\scripts\Build-InnoDll.cmd -Platform x64
```

Other valid variants:

```bat
.\scripts\Build-InnoDll.cmd -Platform x86
.\scripts\Build-InnoDll.cmd -Platform both
```

Important:

- Do not assume `TrackerPlayback.vcxproj` can be built standalone from a clean checkout.
- The DLL depends on OpenMPT-generated libraries that must be built first.
- The build script is responsible for building those dependency libraries before `TrackerPlayback.dll`.

The expected dependency outputs include:

- `libopenmpt-small.lib`
- `openmpt-minimp3.lib`
- `openmpt-miniz.lib`
- `openmpt-stb_vorbis.lib`
- `openmpt-portaudio.lib`

For x64 they are expected under:

- `TrackerPlayback/ThirdParty/openmpt/build/lib/vs2022win10/x86_64/Release`

For x86 they are expected under:

- `TrackerPlayback/ThirdParty/openmpt/build/lib/vs2022win10/x86/Release`

## Environment Caveats

This repository has already hit several machine-specific Windows build issues. Future agents should keep these in mind before assuming the project itself is broken.

- Some environments expose both `PATH` and `Path`, which can confuse MSBuild child process creation.
- Some environments can start `MSBuild.exe -version` successfully but still fail during actual builds.
- Some environments can launch `devenv.com /?` successfully but fail during real solution/project builds.
- If a user reports host-level exceptions from `MSBuild.exe` or `devenv.com`, distinguish that from project-level compiler/linker failures.

If the user says the script completed successfully, trust that build artifacts may already exist even if earlier attempts from this session failed.

## Inno Setup Integration

The preferred include file for installer scripts is:

- [InnoSetupTrackerPlayback.iss.inc](InnoSetupTrackerPlayback.iss.inc)

The minimal example is:

- [InnoSetupExample.iss](InnoSetupExample.iss)

The wrapper API is path-based, not memory-buffer based. That is intentional because Inno Setup is much easier to integrate with file paths than with unmanaged in-memory module buffers.

## Code Change Guidance

When editing this repo:

- Preserve the existing `cdecl` playback API.
- Preserve the added `stdcall` Inno API.
- Do not remove the explicit linker export behavior in `TrackerPlaybackInno.c` unless you replace it with an equivalent stable export strategy.
- Keep installer-facing function names stable unless the user explicitly asks for a breaking change.
- Prefer additive changes over redesigns in `TrackerPlayback`.

If touching the playback API, update all of:

- `TrackerPlayback/TrackerPlayback.h`
- `TrackerPlayback/TrackerPlayback.c`
- `TrackerPlayback/TrackerPlaybackInno.c`
- `InnoSetupTrackerPlayback.iss.inc`
- `InnoSetupExample.iss`
- `README.md`

## Packaging Output

The intended packaged outputs live under:

- `artifacts/inno/`

Each platform package should contain at least:

- `TrackerPlayback.dll`
- `TrackerPlayback.lib`
- `InnoSetupTrackerPlayback.iss.inc`
- `InnoSetupExample.iss`

## Maintenance Priorities

When choosing what to optimize for, prioritize in this order:

1. Keep the DLL buildable on a normal VS 2022 Windows setup.
2. Keep the Inno Setup `stdcall` surface stable.
3. Avoid regressions in the existing native `cdecl` API.
4. Keep the build script understandable and reproducible.
