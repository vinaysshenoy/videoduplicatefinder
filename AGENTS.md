# AGENTS.md

This file provides guidance to AI coding agents working with code in this repository. User-facing setup, features, data locations and contribution rules are in `README.md`; this file does not repeat them.

## Commands

```bash
# Build everything
dotnet build VideoDuplicateFinder.sln

# Run a frontend from source (JIT)
dotnet run --project VDF.GUI
dotnet run --project VDF.CLI -- scan-and-compare --include /path/to/media
dotnet run --project VDF.Web

# Test suites (same set CI runs in .github/workflows/dotnetcore.yml)
dotnet test VDF.Core.Tests/VDF.Core.Tests.csproj
dotnet test VDF.CLI.Tests/VDF.CLI.Tests.csproj
dotnet test VDF.GUI.Tests/VDF.GUI.Tests.csproj
dotnet test VDF.GUI.HeadlessTests/VDF.GUI.HeadlessTests.csproj
dotnet test VDF.Web.Tests/VDF.Web.Tests.csproj
dotnet test VDF.IntegrationTests/VDF.IntegrationTests.csproj

# Single test / class (xunit)
dotnet test VDF.Core.Tests/VDF.Core.Tests.csproj --filter "FullyQualifiedName~AiComponentsTests.ModelSha256_IsPinned"

# Release-style Native AOT publish (what releases.yml ships)
dotnet publish VDF.GUI/VDF.GUI.csproj -c Release -p:PublishAot=true -r <rid>

# Local macOS .app bundle (artifacts/macos/, wiped on every run)
./build-macos.sh
```

- `VDF.IntegrationTests` needs `ffmpeg` on PATH. Without it the tests skip locally, but fail hard when the `CI` env var is set. Video fixtures are generated at runtime by `VDF.TestSupport/TestVideoGenerator`.
- There is no separate lint step; `.editorconfig` is the style source (tabs for C#, 2-space for csproj/props/yml, spaces for XAML).

## Architecture

- **VDF.Core** holds all scanning logic. The three frontends — **VDF.GUI** (Avalonia, ReactiveUI MVVM), **VDF.CLI** (`vdf-cli`, System.CommandLine) and **VDF.Web** (Blazor Server) — are thin shells over it and reach Core internals via `InternalsVisibleTo` (listed in `VDF.Core.csproj`; add new test/frontend assemblies there).
- **`ScanEngine`** is one partial class split across `ScanEngine*.cs`. A scan is: build file list against the database (`BuildFileList`, which also relinks moved files by OsHash) → gather info/sample frames per file (`GatherInfos`) → save → `StartCompare` (grayscale/pHash compare, then optional audio partial-clip, AI partial, track-language passes). The database is saved via `checkpointLock` on a timer (`DatabaseCheckpointIntervalMinutes`), on Pause and at phase ends — keep new saves under that lock.
- **Scan database** (`ScannedFiles.db`) is a MemoryPack-serialized `DatabaseWrapper` of `FileEntry` (`VDF.Core/Utils/DatabaseUtils.cs`). AI data lives in separate sidecars (`UnionEmbeddings.db`, `DenseEmbeddings.db`).
- **Two FFmpeg paths**: spawning the `ffmpeg`/`ffprobe` executables (`FFTools/FfmpegEngine.cs`, `FFProbeEngine.cs`) and an in-process binding via FFmpeg.AutoGen (`FFTools/FFmpegNative/`, toggled by `Settings.UseNativeFfmpegBinding`). The native path requires shared libs matching the FFmpeg.AutoGen major (currently 9.x); `FfmpegDownloader` maps library majors to download tags.
- **AI matching** (`VDF.Core/AI/`): the native ONNX Runtime and the DINOv2 model are not bundled — `AiComponents` downloads them on demand (runtime from the `Microsoft.ML.OnnxRuntime` nupkg on nuget.org, model from this repo's `ai-models-v1` release with a HuggingFace fallback), both hash-pinned, and routes the managed wrapper's `DllImport` to the downloaded library. Tests bypass the download via `TestOverrideModelPath` and the checked-in `VDF.TestSupport/TestData/tiny-embedder.onnx`.

## Invariants that break the build or release if ignored

- **Native AOT**: GUI and CLI ship as AOT. JSON goes through source-generated contexts (`CoreJsonContext`, `GuiJsonContext`, `CliJsonContext`, `WebJsonContext`) — register any new serialized type in the matching context. MemoryPack types must be registered in `VDF.Core/Utils/MemoryPackRegistration.cs`. Avoid reflection-based APIs.
- **Locales**: every file in `VDF.GUI/Assets/Locales/` and `VDF.Core/Assets/Locales/` must have exactly the key set of its `en.json` (`LocaleParityTests`, `CoreLocaleParityTests`). Add new keys to all locales.
- **Version**: `VersionPrefix` in `Directory.Build.props` must match the rolling `tag_name` in `.github/workflows/releases.yml` (`VersionConsistencyTests`).
- **Pinned versions that must move together**: `AiComponents.RuntimeVersion` / `RuntimePackageSha512` ↔ the `Microsoft.ML.OnnxRuntime(.Managed)` PackageReferences in Core and the test projects; Avalonia packages across GUI and HeadlessTests; `SkiaSharp` and `SkiaSharp.NativeAssets.Linux` (see the comment in `VDF.GUI.csproj` before touching ReactiveUI or SkiaSharp).
- New source files carry the AGPL header used across the repo.
