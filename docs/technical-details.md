---
layout: default
title: Technical Details
---

# Technical Details

## How It Works

The plugin uses `nvidia-smi` with CSV output mode to gather GPU statistics:

1. A single `NvidiaGpuService` singleton polls `nvidia-smi` once per update cycle.
2. Each widget and the settings UI subscribe to the service with `request(widget, interval)` and release it on destruction.
3. The shared `Timer` runs only while subscribers exist and uses the shortest requested interval, so the fastest widget sets the pace (default: 4000 ms, configurable per widget as 1s–15s).
4. Two guarded `Process` invocations, each never restarted while the previous run is still going:
   - `nvidia-smi --query-gpu=name,index,pci.bus_id,utilization.gpu,utilization.memory,utilization.encoder,utilization.decoder,memory.used,memory.total,temperature.gpu,power.draw --format=csv,noheader,nounits` for GPU-wide stats
   - `nvidia-smi -q -x` for per-process stats: `--query-compute-apps` only reports compute (CUDA) processes, so the plugin parses the XML output instead, whose per-GPU `<processes>` sections list **every** process using the GPU — graphics (`G`) and compute (`C`) alike — with the VRAM each one has allocated
5. `StdioCollector`s capture stdout; when the stream finishes the CSV is parsed line by line. Non-zero exit codes and stderr output all set a shared `statsError` flag (shown as a red-tinted bar icon on every widget) without resetting existing values.
6. State properties are updated and the UI re-renders reactively via QML bindings; the process list is only reassigned when its contents actually changed, avoiding needless list-view churn.

Values `nvidia-smi` reports as `[N/A]` (e.g. power draw on some GPUs) parse to `0` and are treated as unsupported.

## Data Fields

### GPU Activity

`gpuUsage` is `utilization.gpu` (the overall GPU utilization percentage).

| Field | Source key | Description |
|---|---|---|
| `gfxUsage` | `utilization.gpu` | GPU utilization (%) |
| `memUsage` | `utilization.memory` | Memory controller utilization (%) |
| `mediaUsage` | `max(utilization.encoder, utilization.decoder)` | Video encode/decode activity (%) |

### VRAM

| Field | Source key | Description |
|---|---|---|
| `vramUsed` | `memory.used` | Currently allocated VRAM (MiB) |
| `vramTotal` | `memory.total` | Total available VRAM (MiB) |

Display auto-scales: if total < 1024 MiB, values are shown in MiB; otherwise they are converted to GiB with one decimal place.

### Sensors

| Field | Source key | Description |
|---|---|---|
| `temperature` | `temperature.gpu` | GPU temperature (°C) |
| `powerUsage` | `power.draw` | Current power draw (W) |

### Error State

| Field | Set when | Description |
|---|---|---|
| `statsError` | `nvidia-smi` exits non-zero or writes to stderr | Drives the red bar-icon tint; last-known values are kept, not reset |

### Per-Process Metrics (graphics + compute)

All processes using the GPU are shown — graphics (`G`) and compute (`C`) — parsed from the `<processes>` sections of `nvidia-smi -q -x`. `nvidia-smi` does not expose per-process GPU utilization, so the process list carries VRAM usage only. The list is sorted by the selected **Process List Sort** setting; the default is VRAM descending.

| Field | Source key | Description |
|---|---|---|
| `name` | `process_name` | Process name (entries reported as `[Not Found]` are skipped) |
| `pid` | `pid` | Process ID |
| `vram` | `used_memory` | VRAM allocated (MiB) |

## Color Coding

Usage and temperature thresholds are centralized in `components/shared/CommonStyles.qml` and shared by all three popout styles:

| Range | Color | Meaning |
|---|---|---|
| < 70% | `Theme.primary` | Normal |
| 70–90% | `Theme.warning` | Warning |
| > 90% | `Theme.error` | Critical |

| Temperature | Color | Meaning |
|---|---|---|
| < 70°C | `Theme.info` | Normal |
| 70–85°C | `Theme.warning` | Warning |
| > 85°C | `Theme.error` | Critical |

All popout styles (Default, Alternative, Legacy) read the same thresholds, so changing `CommonStyles.qml` updates coloring everywhere consistently.

## Popout Visual Styles

| Style | Key | Components |
|---|---|---|
| **Default** | `"default"` | Three circular arc gauges (GPU %, VRAM, Temp+Power) + engine bars + process list |
| **Alternative** | `"alt"` | Two stat cards (GPU %, VRAM GiB) + chip badges (temp, power) + engine bars + process list |
| **Legacy** | `"legacy"` | Full-width horizontal progress bars + columnar text stats + process list |

## Shared UI Components

| File | Purpose |
|---|---|
| `components/shared/CircleGauge.qml` | Animated arc gauge with glow, label, sublabel, detail text, and auto-scaling fonts |
| `components/shared/EngineBar.qml` | Label + animated horizontal bar + percentage; used for GFX/Memory/Media rows |
| `components/shared/ProgressBar.qml` | Generic animated fill bar; configurable height, radius, colors |
| `components/shared/StatCard.qml` | Rounded card with icon, label, large bold value, and a thin progress bar |
| `components/shared/CommonStyles.qml` | Shared layout constants (`largePanelRadius: 16`, `mediumPanelRadius: 12`, `chipHeight: 48`, etc.) plus the shared usage/temperature color thresholds and `usageColor()`/`temperatureColor()` helpers |

## Animations

- Progress bars use `NumberAnimation` with `Easing.OutCubic` at 300 ms
- Circle gauges use `Theme.mediumDuration`

## Variant Detection and Matching

When the settings UI loads, the plugin runs `nvidia-smi --query-gpu=name,index,pci.bus_id --format=csv,noheader,nounits` once and shows a loading spinner while detection is in progress. Detected GPUs are sorted by PCI address and stored as widget variants.

The PCI bus id reported by `nvidia-smi` (`00000000:01:00.0`) is normalized to the standard domain format (`0000:01:00.0`) for stable matching.

| Variant field | Source / purpose |
|---|---|
| `gpuPci` | Normalized PCI address from `nvidia-smi`; used as the stable identity for matching |
| `originalName` | The detected GPU name; used by the reset action |
| `name` / `icon` | User-editable display name and Material Symbol icon |
| `gpuType` | Kept for settings compatibility; NVIDIA GPUs do not report a type |
| `description` | Human-readable description shown in **Add Widget** |

### Matching rules

- A variant with a matching `gpuPci` is reused; its `name` and `icon` are preserved unless the user resets them.
- Legacy variants that have `gpuIndex` are adopted by position the first time the matching GPU is detected, then matched by PCI on subsequent loads. They are labeled as `legacy` and can be removed in favour of auto-detected ones.

## Plugin Manifest (`plugin.json`)

| Key | Value |
|---|---|
| `id` | `nvidiaGpuMonitor` |
| `version` | `5.1.0` |
| `capabilities` | `dankbar-widget`, `monitoring` |
| `permissions` | `settings_read`, `settings_write`, `process` |
| `requires` | `nvidia-smi` |
