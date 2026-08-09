import QtQuick
import Quickshell

import qs.Common
import qs.Widgets
import qs.Modules.Plugins

import "components/shared" as Shared

PluginComponent {
    id: root

    property string variantId: ""
    property var variantData: null

    onPluginDataChanged: {
        if (root.variantId && Array.isArray(pluginData?.variants) && pluginData.variants.length)
            root.variantData = pluginData.variants.find(v => v.id === root.variantId) || root.variantData;
    }

    property real gpuUsage: 0.0
    property real vramUsed: 0.0
    property real vramTotal: 0.0
    property real vramPercent: 0.0
    property int temperature: 0
    property int powerUsage: 0
    property string gpuName: "NVIDIA GPU"
    property var processes: []
    readonly property bool statsError: NvidiaGpuService.statsError

    property real gfxUsage: 0.0
    property real memUsage: 0.0
    property real mediaUsage: 0.0

    function resetStats() {
        gfxUsage = 0.0;
        memUsage = 0.0;
        mediaUsage = 0.0;
        gpuUsage = 0.0;
        vramUsed = 0.0;
        vramTotal = 0.0;
        vramPercent = 0.0;
        temperature = 0;
        powerUsage = 0;
        processes = [];
    }

    property int updateInterval: Math.max(1000, parseInt(variantData?.updateInterval ?? pluginData.updateInterval ?? "4000") || 4000)

    property bool minimumWidth: variantData?.minimumWidth ?? pluginData.minimumWidth ?? true
    property int gpuIndex: Math.max(0, parseInt(variantData?.gpuIndex ?? "0") || 0)
    // gpuIndex is kept only as a fallback for variants created before PCI
    // matching; nvidia-smi reports all GPUs in index order.
    property string gpuPci: (variantData?.gpuPci ?? "").toString()
    property string popoutStyle: variantData?.popoutStyle ?? pluginData.popoutStyle ?? "default"
    readonly property string widgetIcon: (variantData?.icon && String(variantData.icon)) ? variantData.icon : "memory"
    readonly property string displayName: (variantData?.name && String(variantData.name)) ? variantData.name : root.gpuName
    property int processListHeight: Math.max(100, Math.min(750, parseInt(variantData?.processListHeight ?? pluginData.processListHeight ?? "250") || 250))
    property string processSort: (variantData?.processSort ?? pluginData.processSort ?? "vram").toString()
    readonly property string popoutStyleSource: {
        switch (popoutStyle) {
            case "alt":
                return "components/styles/AltStyle.qml";
            case "legacy":
                return "components/styles/LegacyStyle.qml";
            default:
                return "components/styles/DefaultStyle.qml";
        }
    }

    Shared.CommonStyles {
        id: commonStyles
    }

    Component.onCompleted: {
        NvidiaGpuService.request(root, root.updateInterval);
        if (NvidiaGpuService.devices.length)
            applyStats();
    }
    Component.onDestruction: NvidiaGpuService.release(root)

    onUpdateIntervalChanged: NvidiaGpuService.request(root, root.updateInterval)

    onGpuPciChanged: applyStats()
    onProcessSortChanged: applyStats()

    Connections {
        target: NvidiaGpuService
        function onDevicesChanged() {
            root.applyStats();
        }
    }

    function applyStats() {
        const device = root.gpuPci
            ? NvidiaGpuService.deviceByPci(root.gpuPci)
            : NvidiaGpuService.deviceByIndex(root.gpuIndex) || NvidiaGpuService.deviceByIndex(0);

        if (!device) {
            root.resetStats();
            root.gpuName = "NVIDIA GPU";
            return;
        }

        const selectedGpu = device.stats;
        root.gpuName = device.name;

        // nvidia-smi has no single "media engine" value; the encoder
        // and decoder utilization are the closest proxies.
        root.gfxUsage = selectedGpu.gpuUsage;
        root.memUsage = selectedGpu.memUsage;
        root.mediaUsage = Math.max(selectedGpu.encoderUsage, selectedGpu.decoderUsage);
        root.gpuUsage = selectedGpu.gpuUsage;

        root.vramUsed = selectedGpu.vramUsed;
        root.vramTotal = selectedGpu.vramTotal;
        root.vramPercent = root.vramTotal > 0
            ? (root.vramUsed / root.vramTotal * 100) : 0.0;
        root.temperature = selectedGpu.temperature;
        root.powerUsage = Math.round(selectedGpu.powerUsage);

        const processList = device.processes.slice();
        processList.sort(root.compareProcesses);
        if (!root.processListsEqual(root.processes, processList))
            root.processes = processList;
    }

    function processListsEqual(a, b) {
        if (a.length !== b.length)
            return false;
        return JSON.stringify(a) === JSON.stringify(b);
    }

    function compareProcesses(a, b) {
        switch (root.processSort) {
            case "gfx":
                return b.gfx - a.gfx;
            case "cpu":
                return b.cpu - a.cpu;
            case "name":
                return (a.name || "").localeCompare(b.name || "");
            case "pid":
                return a.pid - b.pid;
            case "vram":
            default:
                return b.vram - a.vram;
        }
    }

    function formatVram() {
        if (root.vramTotal < 1024) {
            return `${root.vramUsed.toFixed(0)}/${root.vramTotal.toFixed(0)} MiB`;
        }

        const usedGiB = (root.vramUsed / 1024).toFixed(1);
        const totalGiB = (root.vramTotal / 1024).toFixed(1);
        return `${usedGiB}/${totalGiB} GiB`;
    }

    function getUsageColor(percent) {
        return commonStyles.usageColor(percent);
    }

    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingS

            DankIcon {
                name: root.widgetIcon
                size: root.iconSize
                color: root.statsError ? Theme.error : Theme.widgetIconColor
                anchors.verticalCenter: parent.verticalCenter
            }

            Item {
                anchors.verticalCenter: parent.verticalCenter
                implicitWidth: root.minimumWidth ? Math.max(textBaseline.width, currentTextMetrics.width) : currentTextMetrics.width
                implicitHeight: currentTextMetrics.height
                width: implicitWidth
                height: implicitHeight

                Behavior on width {
                    NumberAnimation {
                        duration: Theme.shortDuration
                        easing.type: Easing.OutCubic
                    }
                }

                StyledTextMetrics {
                    id: textBaseline
                    font.pixelSize: Theme.fontSizeSmall
                    text: "88% | 8.8GiB"
                }

                StyledTextMetrics {
                    id: currentTextMetrics
                    font.pixelSize: Theme.fontSizeSmall
                    text: `${root.gpuUsage.toFixed(0)}% | ${(root.vramUsed / 1024).toFixed(1)}GiB`
                }

                StyledText {
                    id: gpuText
                    text: currentTextMetrics.text
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.widgetTextColor
                    anchors.fill: parent
                    wrapMode: Text.NoWrap
                    maximumLineCount: 1
                    elide: Text.ElideNone
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }
    }

    verticalBarPill: Component {
        Column {
            spacing: 1

            DankIcon {
                name: root.widgetIcon
                size: root.iconSize
                color: root.statsError ? Theme.error : Theme.widgetIconColor
                anchors.horizontalCenter: parent.horizontalCenter
            }

            StyledText {
                text: `${root.gpuUsage.toFixed(0)}%`
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.widgetTextColor
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }

    popoutContent: Component {
        PopoutComponent {
            id: popout
            showCloseButton: true
            headerText: root.displayName

            Loader {
                id: popoutLoader
                width: parent.width
                function loadStyle() {
                    setSource(root.popoutStyleSource, { "root": root });
                }

                Component.onCompleted: loadStyle()
                Connections {
                    target: root
                    function onPopoutStyleSourceChanged() {
                        popoutLoader.loadStyle();
                    }
                }
            }
        }
    }
}
