---
layout: default
title: Documentation
---

# NVIDIA GPU Monitor Documentation

Welcome to the NVIDIA GPU Monitor documentation. This plugin (v5.0.0) provides real-time monitoring of NVIDIA GPU statistics for DankMaterialShell.

## Quick Navigation

### Getting Started
- [**Installation Guide**](installation) - Set up the plugin and dependencies
- [**Configuration**](configuration) - Customize behavior and appearance

### Help & Reference
- [**Troubleshooting**](troubleshooting) - Common issues and solutions
- [**Technical Details**](technical-details) - How it works and data fields

## Overview

NVIDIA GPU Monitor tracks:
- GPU usage — `utilization.gpu`, `utilization.memory`, and encoder/decoder activity via `nvidia-smi`
- VRAM statistics with auto-scaling display (MiB or GiB)
- Temperature (°C) and power consumption (W)
- Per-process GPU metrics (process name, PID, VRAM) — all processes using the GPU, graphics and compute alike, parsed from `nvidia-smi -q -x`

## Screenshots

![NVIDIA GPU Monitor](images/screenshot.png)

## Quick Links

- [GitHub Repository](https://github.com/Reverssss/dms-nvidia-gpu-monitor)
- [Report an Issue](https://github.com/Reverssss/dms-nvidia-gpu-monitor/issues)
- [DankMaterialShell](https://github.com/DankMaterialShell)

## Features at a Glance

- Real-time GPU monitoring
- VRAM usage tracking
- Temperature and power metrics
- Per-process statistics
- Color-coded indicators
- Smooth animations
- Three popout visual styles (Default, Alternative, Legacy)
- Configurable update interval (1s–15s)
- Multi-GPU widget variants with automatic PCI-based detection
- Inline editing of widget display names and icons
- Loading indicator while GPUs are detected
- Settings UI — no manual file editing required
