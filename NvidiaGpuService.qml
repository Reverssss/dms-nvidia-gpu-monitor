pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// nvidia-smi reports every GPU in a single call, and DankBar builds one bar
// per screen, so polling here keeps it at one call per tick instead of one per
// widget per screen.
Singleton {
    id: root

    readonly property int defaultInterval: 4000

    // Every GPU nvidia-smi reported, each carrying name, pci, its parsed stats
    // and the processes currently using it.
    property var devices: []
    property bool statsError: false

    // Keyed by widget so the copies of a variant mirrored across screens hold a
    // slot each, and releasing one never cancels the others.
    property var subscribers: []

    function request(widget, interval) {
        const entry = subscribers.find(s => s.widget === widget);
        if (entry)
            entry.interval = Math.max(1000, interval || defaultInterval);
        else
            subscribers.push({ widget: widget, interval: Math.max(1000, interval || defaultInterval) });
        sync();
    }

    function release(widget) {
        subscribers = subscribers.filter(s => s.widget !== widget);
        sync();
    }

    // The fastest widget sets the pace, so a widget at 1s still updates at 1s.
    function sync() {
        updateTimer.interval = subscribers.length
            ? Math.min(...subscribers.map(s => s.interval))
            : defaultInterval;
        updateTimer.running = subscribers.length > 0;
    }

    function deviceByPci(pci) {
        return pci ? devices.find(d => d.pci === pci) || null : null;
    }

    // nvidia-smi always reports every GPU in index order, awake or not.
    function deviceByIndex(index) {
        return devices[index] || null;
    }

    // Normalizes nvidia-smi's "00000000:01:00.0" bus id to the standard
    // "0000:01:00.0" domain format used for stable variant matching.
    function normalizePci(busId) {
        if (typeof busId !== "string")
            return "";

        const s = busId.trim().toLowerCase();
        if (/^[0-9a-f]{4}:[0-9a-f]{2}:[0-9a-f]{2}\.[0-7]$/.test(s))
            return s;
        if (/^[0-9a-f]{8}:[0-9a-f]{2}:[0-9a-f]{2}\.[0-7]$/.test(s))
            return s.substring(4);
        return "";
    }

    Timer {
        id: updateTimer
        interval: root.defaultInterval
        running: false
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!pollStatsProcess.running)
                pollStatsProcess.running = true;
            if (!pollProcessesProcess.running)
                pollProcessesProcess.running = true;
        }
    }

    Process {
        id: pollStatsProcess
        command: [
            "nvidia-smi",
            "--query-gpu=name,index,pci.bus_id,utilization.gpu,utilization.memory,utilization.encoder,utilization.decoder,memory.used,memory.total,temperature.gpu,power.draw",
            "--format=csv,noheader,nounits"
        ]
        running: false

        onExited: exitCode => {
            if (exitCode !== 0) {
                root.statsError = true;
                console.warn(`nvidiaGpuMonitor: nvidia-smi exited with code ${exitCode}`);
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                const errorText = text.trim();
                if (errorText.length > 0) {
                    root.statsError = true;
                    console.warn(`nvidiaGpuMonitor: ${errorText}`);
                }
            }
        }

        stdout: StdioCollector {
            onStreamFinished: {
                const output = text.trim();
                if (output.length === 0)
                    return;

                root.statsError = false;

                const parsed = [];
                const lines = output.split("\n");
                for (const line of lines) {
                    const fields = line.split(", ");
                    if (fields.length < 11)
                        continue;

                    const pci = root.normalizePci(fields[2]);
                    if (!pci)
                        continue;

                    parsed.push({
                        name: fields[0] || "NVIDIA GPU",
                        index: parseInt(fields[1]),
                        pci: pci,
                        type: "",
                        suspended: false,
                        stats: {
                            gpuUsage: parseFloat(fields[3]) || 0.0,
                            memUsage: parseFloat(fields[4]) || 0.0,
                            encoderUsage: parseFloat(fields[5]) || 0.0,
                            decoderUsage: parseFloat(fields[6]) || 0.0,
                            vramUsed: parseFloat(fields[7]) || 0.0,
                            vramTotal: parseFloat(fields[8]) || 0.0,
                            temperature: parseInt(fields[9]) || 0,
                            powerUsage: parseFloat(fields[10]) || 0.0
                        },
                        processes: []
                    });
                }

                // The stats query carries no process data; carry over the last
                // process lists so a stats-only poll never wipes them.
                for (const gpu of parsed) {
                    const existing = root.devices.find(d => d.pci === gpu.pci);
                    if (existing && existing.processes.length)
                        gpu.processes = existing.processes;
                }

                if (!root.devicesEqual(root.devices, parsed))
                    root.devices = parsed;
            }
        }
    }

    Process {
        id: pollProcessesProcess
        // --query-compute-apps only reports compute (CUDA) processes, so the
        // XML output is used instead: its per-GPU <processes> sections list
        // every process using the GPU (graphics "G" and compute "C" alike)
        // with the VRAM each one has allocated.
        command: [
            "nvidia-smi",
            "-q",
            "-x"
        ]
        running: false

        onExited: exitCode => {
            if (exitCode !== 0)
                console.warn(`nvidiaGpuMonitor: nvidia-smi -q -x exited with code ${exitCode}`);
        }

        stdout: StdioCollector {
            onStreamFinished: {
                const output = text.trim();
                if (output.length === 0)
                    return;

                const gpuBlocks = [];
                const gpuRegex = /<gpu id="([^"]+)">([\s\S]*?)<\/gpu>/g;
                let match;
                while ((match = gpuRegex.exec(output)) !== null) {
                    gpuBlocks.push({ pci: root.normalizePci(match[1]), body: match[2] });
                }

                const byPci = {};
                for (const block of gpuBlocks) {
                    const processList = [];
                    const procRegex = /<process_info>([\s\S]*?)<\/process_info>/g;
                    let procMatch;
                    while ((procMatch = procRegex.exec(block.body)) !== null) {
                        const entry = procMatch[1];
                        const pid = parseInt(entry.match(/<pid>([^<]*)<\/pid>/)?.[1] ?? "");
                        if (isNaN(pid))
                            continue;

                        const name = (entry.match(/<process_name>([^<]*)<\/process_name>/)?.[1] ?? "").trim();
                        if (!name || name === "[Not Found]")
                            continue;

                        const memText = entry.match(/<used_memory>([^<]*)<\/used_memory>/)?.[1] ?? "";
                        const vram = parseFloat(memText) || 0.0;

                        processList.push({
                            name: name,
                            pid: pid,
                            vram: vram,
                            vramUnit: "MiB",
                            gfx: 0.0,
                            cpu: 0.0,
                            gtt: 0.0,
                            compute: 0.0
                        });
                    }
                    byPci[block.pci] = processList;
                }

                const updated = [];
                for (const device of root.devices) {
                    updated.push({
                        name: device.name,
                        index: device.index,
                        pci: device.pci,
                        type: device.type,
                        suspended: device.suspended,
                        stats: device.stats,
                        processes: byPci[device.pci] || device.processes
                    });
                }

                if (!root.devicesEqual(root.devices, updated))
                    root.devices = updated;
            }
        }
    }

    function devicesEqual(a, b) {
        if (a.length !== b.length)
            return false;
        return JSON.stringify(a) === JSON.stringify(b);
    }
}
