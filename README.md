# Medieval Dynasty Trajectory Preview

Shows a live projectile path and highlights the first target hit. Supports bows,
crossbows and spears, including a full-power guide before drawing. First-person,
third-person and co-op have been tested in play.

## Requirements

- Medieval Dynasty, Steam Windows build **23681518**. Other builds are not supported.
- [UE4SS](https://github.com/UE4SS-RE/RE-UE4SS/releases), tested with
  **v3.0.1-1127-g2bfa839f**, included in the Bundled download.

The mod checks the executable identity before using build-specific collision
layouts. A game update may require a mod update.

## Install

1. Download `TrajectoryPreview-0.6.13-Bundled.zip` for a new installation.
   If UE4SS is already installed, use the smaller ZIP without `-Bundled` instead.
2. Open Steam → Medieval Dynasty → Manage → Browse local files. Extract the ZIP
   here, merging `Medieval_Dynasty`. The Bundled ZIP includes UE4SS; do not
   overwrite an existing UE4SS installation with it.
3. Add `-fileopenlog` to the game's launch options for the tested pak-loading setup.
4. Start the game and equip a supported weapon with ammunition.

`-fileopenlog` is a diagnostic flag, but UE4.27 also disables pak signature checks
and pak precaching with it. This mod's material paks were tested with that flag;
loading them without it has not been verified.

If Windows reports a missing `VCRUNTIME140` or `MSVCP140` DLL, install the
[Microsoft Visual C++ x64 runtime](https://aka.ms/vs/17/release/vc_redist.x64.exe).
Steam normally installs game prerequisites, but an older runtime may need updating.

The ZIP installs scripts under `Medieval_Dynasty/Binaries/Win64/ue4ss/Mods/TrajectoryPreview`
and two material paks under `Medieval_Dynasty/Content/Paks`. Do not use GitHub's
automatic source archive as an installable mod.

**Ctrl+Shift+F6** toggles the preview. Preferences are saved beside the scripts.
The mod changes local presentation only; it does not fire weapons or edit saves.
Diagnostics are disabled by default. Set `telemetry=true` in `Scripts/config.lua`
when troubleshooting; logs are written to `ue4ss/UE4SS.log`.

To uninstall, remove `Mods/TrajectoryPreview`, `MDTrajectoryThread_P.pak` and
`MDTrajectoryOutline_P.pak`. Keep UE4SS if other mods use it. If this was your only UE4SS mod, you can also
remove the bundled `Binaries/Win64/dwmapi.dll` and `Binaries/Win64/ue4ss` folder.

## Supported equipment

- Bow, Longbow, Recurve Bow and The Silencing Wind.
- Wooden and iron crossbows.
- Wooden, stone, copper, bronze and iron spears, plus the fishing spear.
- Normal and poisoned arrows/bolts, and Arrows of Randomness.

Individual equipment combinations have automated checks, but have not all been
measured in game. The preview hides during reloads, menus and unsupported states.

## Development

Python 3.11+ with the pinned test dependency:

```sh
python -m pip install -r requirements-dev.txt
python tooling/test-mod.py
python tooling/test-analyzer.py
python tooling/test-package.py
python tooling/package-mod.py --all
```

Use `python tooling/test-mod.py --list` or pass test names to run a subset.
`profiles.lua` defines equipment and engine fields; `state.lua` captures launch
inputs; `predict.lua` and `batched_prediction.lua` handle flight; `preview.lua`
connects collision and renderers. Tests isolate Lua runtimes and mock engine calls.

Material authoring scripts and shaders are in `tooling/outline-material` for
Unreal Editor 4.27. The checked-in paks are the tested Windows SM5 material builds.
CI packages these assets; it does not run Unreal Editor or recook shaders.

CI tests and packages both ZIPs on pushes and pull requests. Pushing a tag
matching `VERSION` (for example `v0.6.13`) publishes a GitHub release with the
exact tested archives and SHA-256 checksums. Tag only a release-ready commit.

`vendor/ue4ss` contains the pinned upstream runtime, provenance, checksums and
licenses. Packaging verifies its checksums before including it. The bundled
loader has its console disabled and includes no sample mods or debug symbols.
UE4SS uses the MIT license; bundled component notices accompany the runtime.
