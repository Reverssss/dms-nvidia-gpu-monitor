# NVIDIA GPU Monitor

Real-time NVIDIA GPU monitoring plugin for DankMaterialShell. Tracks GPU usage, VRAM, temperature, power, and per-process activity for NVIDIA GPUs, with support for multiple GPU-specific widget variants.

![Screenshot](docs/images/screenshot.png)

## Features

- GPU usage monitoring (GPU, Memory Controller, Encoder/Decoder) via `nvidia-smi`
- VRAM statistics with auto-scaling display (MiB or GiB)
- Temperature and power tracking
- Per-process GPU metrics (process name, PID, VRAM) — includes both graphics and compute processes, parsed from `nvidia-smi -q -x`
- Color-coded indicators (normal < 70% / warning 70–90% / critical > 90%)
- Smooth animations on all bars and gauges
- Three switchable popout visual styles:
  - `Default` — circular gauges
  - `Alternative` — stat cards and chips
  - `Legacy` — compact text and progress bars
- Configurable process list sorting (VRAM, GFX, CPU, Name, PID)
- Hover tooltips show the full name when a process label is truncated
- Multi-GPU widget variants — create separate widgets for GPU 0, GPU 1, and so on
- Efficient shared polling — one `nvidia-smi` call per tick for all widgets and screens
- Configurable via DankMaterialShell settings UI — no manual file editing required

## Quick Start

### Requirements

- NVIDIA GPU with the proprietary NVIDIA driver
- [`nvidia-smi`](https://developer.nvidia.com/nvidia-system-management-interface) (ships with the NVIDIA driver)
- QuickShell
- DankMaterialShell

#### Install `nvidia-smi`

`nvidia-smi` is bundled with the NVIDIA driver. Install the driver for your distribution:

```bash
# Arch
yay -S nvidia

# Debian/Ubuntu
sudo apt install nvidia-driver

# Fedora
sudo dnf install akmod-nvidia
```

Verify it works:

```bash
nvidia-smi
```

### Installation

Install the plugin via the DankMaterialShell  <a href="dms://plugin/install/nvidiaGpuMonitor">plugin store</a>, or manually:

```bash
git clone https://github.com/navidagz/dms-nvidia-gpu-monitor.git ~/.config/DankMaterialShell/plugins/nvidiaGpuMonitor
```

Then:

1. Open DMS Settings -> Plugins
2. Scan for plugins if needed
3. Enable `NVIDIA GPU Monitor`
4. Add the widget to your bar from DMS Settings -> Bar / Widgets

## Bar Display

**Horizontal bar:** shows `GPU% | VRAM-used`, for example:

```text
45% | 6.2GiB
```

**Vertical bar:** shows the icon and GPU usage percentage only.

## Usage

**Popout Panel:** Click the widget to open detailed metrics for the selected GPU: device name, engine activity, VRAM, temperature, power, and a process list.

### Popout Styles

The popout style is controlled in the plugin settings under **Popout Style**:

| Style | Description |
|---|---|
| `Default` | Circular gauges for GPU, VRAM, and temperature |
| `Alternative` | Stat-card layout with chip-style temperature and power indicators |
| `Legacy` | Classic text layout with horizontal progress bars |

You can switch styles at runtime from the DMS plugin settings UI.

### Multi-GPU Variants

<img src="docs/images/settings.png" align="right" width="400">

GPUs are auto-detected via PCI address — no manual index entry needed. Each detected GPU gets its own widget variant automatically. All widgets share a single `nvidia-smi` poll, so adding more GPUs or screens does not multiply CPU overhead.

Use this when you want:

- one bar widget for your discrete GPU
- another bar widget for your integrated GPU
- separate widgets for each GPU in a multi-GPU system

To add a GPU widget to your bar:

1. Open DMS Settings -> Plugins -> NVIDIA GPU Monitor
2. Scroll to **Configured Widgets** — each detected GPU already has a variant
3. Go to **Add Widget** and pick the variant you want

You can also **edit** a variant's display name and icon inline: click the edit (pencil) button, change the name and Material Symbol icon, then save. Use the reset button to restore the original detected name and icon.

Legacy variants from older plugin versions appear with a `(legacy)` tag and can be safely removed.

<br clear="right"/>

## Settings

Available in the DMS settings UI:

| Setting | Description |
|---|---|
| `Force Padding` | Keeps the horizontal bar width stable as values change. |
| `Popout Style` | Switches between `Default`, `Alternative`, and `Legacy`. |
| `Update Interval` | Controls how often `nvidia-smi` is polled (1s–15s). Lower values are more responsive but use more CPU. The fastest interval requested by any active widget drives the shared poll timer. |
| `Process List Height` | Controls the maximum process list height in the popout. The widget clamps the effective value to its supported range. |
| `Process List Sort` | Sorts the popout process list by VRAM Usage, GPU Usage (GFX), CPU Usage, Process Name, or PID. |
| `GPU Variants` | Lists auto-detected GPUs and lets you edit widget display names and icons inline. |

## Notes

- Each variant stores its GPU by PCI address, so the correct GPU is always targeted even after hardware changes.
- The GPU engine activity section maps `utilization.gpu` to GFX, `utilization.memory` to MEM, and the max of `utilization.encoder`/`utilization.decoder` to Media.
- The process list covers **all** processes using the GPU — graphics and compute alike (parsed from `nvidia-smi -q -x`), each with its VRAM usage. Per-process GPU utilization is not exposed by `nvidia-smi`. Values that `nvidia-smi` reports as `[N/A]` (e.g. power draw on some GPUs) are shown as disabled/hidden rather than garbage.

## Documentation

[Full Documentation](https://Reverssss.github.io/dms-nvidia-gpu-monitor/docs/)

- [Installation Guide](docs/installation.md)
- [Configuration](docs/configuration.md)
- [Troubleshooting](docs/troubleshooting.md)
- [Technical Details](docs/technical-details.md)

## License

MIT License — Copyright 2026 Revers.

## Credits

Built for [DankMaterialShell](https://github.com/DankMaterialShell) • Uses [nvidia-smi](https://developer.nvidia.com/nvidia-system-management-interface)

Thanks to [@navidagz](https://github.com/navidagz) for the original project.
