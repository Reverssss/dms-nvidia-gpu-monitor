---
layout: default
title: Troubleshooting
---

# Troubleshooting

## Plugin not showing data

### Check if nvidia-smi is installed
```bash
which nvidia-smi
nvidia-smi
```

The second command should print a table with your GPU(s). If it errors or hangs, the plugin will not work.

### Verify the NVIDIA driver is loaded
```bash
lsmod | grep nvidia
nvidia-smi -L
```

### Check nvidia-smi query output
```bash
nvidia-smi --query-gpu=name,index,pci.bus_id,utilization.gpu,memory.used,memory.total,temperature.gpu,power.draw --format=csv,noheader,nounits
```

## Permission issues

Some systems may require additional permissions to access GPU metrics:

```bash
# Add user to video group
sudo usermod -a -G video $USER
# Log out and back in for changes to take effect
```

## No process data

The per-process list will be empty if:

- No processes are actively using the GPU
- The process names come back as `[Not Found]` (insufficient permissions to read `/proc`); those entries are skipped
- `nvidia-smi -q -x` fails or returns no `<processes>` sections

## Common Issues

### Widget shows 0% usage despite GPU activity

- Ensure `nvidia-smi` runs without errors: `nvidia-smi`
- Verify the driver is loaded: `lsmod | grep nvidia`
- Test the query directly (see above)

### Bar widget keeps resizing

Enable **Force Padding** in the plugin settings. This pads the widget to a fixed minimum width so it does not resize as values update.

### High CPU usage from the plugin

The plugin shares one `nvidia-smi` poll across all widgets and screens, so CPU usage stays low even with multiple GPU widgets. If overhead is still noticeable, increase the **Update Interval** setting in the plugin settings UI to reduce polling frequency. The default is 4s; setting it to 8s or 15s will cut overhead further.

### Widget icon turns red / stats stop updating

The plugin surfaces a `statsError` state when `nvidia-smi` exits non-zero or writes to stderr. The bar icon tints red as an indicator. Check:

- `nvidia-smi` runs cleanly (see above)
- Permissions/group membership per "Permission issues" above

The widget keeps its last-known values during a transient error instead of resetting to zero, so a single bad poll will self-heal on the next cycle once corrected.

### Popout panel is blank or fails to load

A mismatch between the selected `popoutStyle` and the available style files can cause the loader to fail silently. Reset the **Popout Style** setting to `default` in the settings UI.
