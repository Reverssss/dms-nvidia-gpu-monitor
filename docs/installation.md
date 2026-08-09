---
layout: default
title: Installation Guide
---

# Installation Guide

## Requirements

- NVIDIA GPU with the proprietary NVIDIA driver
- `nvidia-smi` utility installed and accessible in PATH
- QuickShell
- DankMaterialShell framework

## Installing nvidia-smi

`nvidia-smi` is bundled with the NVIDIA driver package. Install the driver for your distribution:

### Arch Linux
```bash
yay -S nvidia
```

### Debian / Ubuntu
```bash
sudo apt install nvidia-driver
```

### Fedora
```bash
sudo dnf install akmod-nvidia
```

Verify the installation:

```bash
nvidia-smi
```

This should print a table with your GPU(s), driver version, and memory stats.

## Installing the Plugin

1. Copy the plugin folder to your DankMaterialShell plugins directory:
   ```bash
   cp -r NvidiaGpuMonitor ~/.config/DankMaterialShell/plugins/
   ```

2. The plugin is automatically detected by DankMaterialShell on next startup.

## Permissions

`nvidia-smi` normally runs without extra permissions. If process queries come back empty or the plugin reports errors, check that your user is in the `video` group:

```bash
# Add user to video group
sudo usermod -a -G video $USER
# Log out and back in for changes to take effect
```
