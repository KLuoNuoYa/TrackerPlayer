# Tracker Player

## Part of this plugin is developed using ChatGPT-5.4 and its stability cannot be guaranteed. There is a high probability that the author will not provide further updates for it.

Tracker Player is a lightweight Windows tracker-module playback solution built around a reusable native playback library. The project now consists of three layers:

- TrackerPlayback — a native DLL that exposes a small C playback API
- TrackerPlayer — a minimal Win32 executable for command-line playback and single-instance control
- TrackerPlaybackTest — a WPF test application for interactive validation of the DLL

Audio decoding is handled by `libopenmpt`, and audio output is handled by `PortAudio`.

## Architecture Overview

### 1. TrackerPlayback

TrackerPlayback is the core playback engine. It is a native DLL written in C and exposes a stable procedural API through `TrackerPlayback.h`.

Exported capabilities include:

- setting an error callback
- setting a playback status callback
- querying current playback status
- starting playback from an in-memory module buffer
- stopping playback
- pausing playback
- resuming playback

Playback statuses:

- `TRACKER_PLAYBACK_STATUS_STOPPED`
- `TRACKER_PLAYBACK_STATUS_PLAYING`
- `TRACKER_PLAYBACK_STATUS_PAUSED`

Implementation details:

- module data is passed in as a memory buffer rather than a file path
- decoding uses `openmpt_module_create_from_memory2`
- playback runs on a worker thread
- synchronization uses Win32 events and a critical section
- audio output targets stereo `float32` samples at `48000 Hz`
- the engine first tries non-interleaved output and falls back to interleaved output when needed
- loop behavior is controlled by the caller

### 2. TrackerPlayer

TrackerPlayer is a small Win32 frontend that uses `TrackerPlayback.dll`.

Responsibilities:

- parses the command line
- loads the selected module file into memory
- passes that memory buffer to `TrackerPlayback_Play`
- shows message boxes for startup and playback failures
- keeps a hidden message window alive during playback
- enforces single-instance behavior through a named mutex

Single-instance behavior:

- if no module path is provided, the app shows an error
- if another instance is already running and no module path is provided, the running instance is asked to stop
- if another instance is already running and a module path is provided, the new instance exits with an error message

### 3. TrackerPlaybackTest

TrackerPlaybackTest is a WPF desktop test harness for the DLL.

It provides:

- file browsing for tracker modules
- play / pause / resume / stop controls
- optional loop playback
- current status display
- a log view for callback and operation messages

This project is useful for validating the playback API independently from the native command-line player.

## Repository Structure

- `TrackerPlayback/` — native playback DLL project
	- `TrackerPlayback.h` — public C API
	- `TrackerPlayback.c` — playback engine implementation
	- `TrackerPlaybackInternal.h` — internal state and constants
	- `ThirdParty/openmpt/` — bundled `libopenmpt` source tree
- `TrackerPlayer/` — native Win32 player executable
	- `Main.c` — application entry point and instance-control logic
- `TrackerPlaybackTest/` — WPF validation app
	- `TrackerPlayback.cs` — P/Invoke wrapper for the DLL API
	- `MainWindow.xaml` / `MainWindow.xaml.cs` — UI and playback interactions
- `FunkyStars.xm` — sample module file
- `TrackerPlayer.slnx` — solution workspace entry

## Public Playback API

The DLL exposes the following functions:

- `TrackerPlayback_SetErrorCallback`
- `TrackerPlayback_SetStatusCallback`
- `TrackerPlayback_GetStatus`
- `TrackerPlayback_Play`
- `TrackerPlayback_Stop`
- `TrackerPlayback_Pause`
- `TrackerPlayback_Resume`
- `TrackerPlayback_Inno_PlayFile`
- `TrackerPlayback_Inno_Stop`
- `TrackerPlayback_Inno_Pause`
- `TrackerPlayback_Inno_Resume`
- `TrackerPlayback_Inno_GetStatus`
- `TrackerPlayback_Inno_GetLastErrorCode`

`TrackerPlayback_Play` accepts:

- a pointer to module data in memory
- the size of that buffer
- a loop flag indicating whether playback should repeat forever

The `TrackerPlayback_Inno_*` exports are intended for installers and other scripting hosts that prefer `stdcall` entry points and file-path based playback.

## Usage

### Native player

Run the executable with a module file path:

`TrackerPlayer.exe FunkyStars.xm`

Typical flow:

1. the player resolves the file path
2. the module file is loaded fully into memory
3. the memory buffer is passed to `TrackerPlayback.dll`
4. playback continues until stopped, the window receives a stop message, or the module ends

### WPF test app

Use `TrackerPlaybackTest` when you want to:

- verify the exported DLL API
- test pause and resume behavior
- inspect callback notifications
- validate module loading without going through the native single-instance app

## Supported Behavior

Current implementation supports:

- tracker-module playback through `libopenmpt`
- in-memory module loading
- playback state transitions: stopped, playing, paused
- looped or non-looped playback
- Win32 and x64 builds
- native and managed test frontends

## Build Notes

- primary native code is written in C
- the test frontend is written in C# / WPF
- playback depends on `libopenmpt` and `PortAudio`
- the repository includes Visual Studio project files for the native player, native DLL, and WPF test app
- initialize the bundled OpenMPT dependency before building:
  `git submodule update --init --recursive`

When building the full solution, ensure the DLL is available beside the consuming executable or test application.

### One-command Inno DLL build

If you only need the installer-facing DLL package, use:

`scripts\Build-InnoDll.cmd`

Do not build `TrackerPlayback.vcxproj` by itself before the dependency step has run. The DLL links against libraries generated from the bundled OpenMPT tree, and those `.lib` files are produced by the script first.

Useful variants:

- `scripts\Build-InnoDll.cmd -Platform x86`
- `scripts\Build-InnoDll.cmd -Platform x64`
- `scripts\Build-InnoDll.cmd -Platform both`

The script will:

- locate Visual Studio through `vswhere`
- normalize the child-process environment before launching MSBuild
- build `libopenmpt-small`
- build the `portaudio` target from `libopenmpt`
- build the `TrackerPlayback` DLL with the Inno `stdcall` exports
- package ready-to-use outputs under `artifacts\inno`

Generated packages:

- `artifacts\inno\x86\TrackerPlayback.dll`
- `artifacts\inno\x64\TrackerPlayback.dll`
- `artifacts\inno\TrackerPlayback-Inno-x86.zip`
- `artifacts\inno\TrackerPlayback-Inno-x64.zip`

Each package also includes:

- `InnoSetupTrackerPlayback.iss.inc`
- `InnoSetupExample.iss`

## Inno Setup

`TrackerPlayback.dll` now includes a second, installer-friendly API surface:

- `TrackerPlayback_Inno_PlayFile(const wchar_t* modulePath, int loopForever)`
- `TrackerPlayback_Inno_Stop(void)`
- `TrackerPlayback_Inno_Pause(void)`
- `TrackerPlayback_Inno_Resume(void)`
- `TrackerPlayback_Inno_GetStatus(void)`
- `TrackerPlayback_Inno_GetLastErrorCode(void)`

These exports are:

- `stdcall`
- path-based instead of memory-buffer based
- exported with undecorated names so they can be bound from Inno Setup using their plain identifier

Use [InnoSetupTrackerPlayback.iss.inc](InnoSetupTrackerPlayback.iss.inc) to import the declarations into your setup script, or start from [InnoSetupExample.iss](InnoSetupExample.iss).

## License

This project is licensed under the MIT License. See [LICENSE.md](LICENSE.md) for details.
