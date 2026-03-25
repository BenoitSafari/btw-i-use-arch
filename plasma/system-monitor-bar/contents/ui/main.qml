import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as Plasma5
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    preferredRepresentation: fullRepresentation
    Layout.preferredWidth: row.implicitWidth + Kirigami.Units.smallSpacing * 2
    Layout.preferredHeight: Kirigami.Units.iconSizes.small

    property real cpuUsage: 0
    property real ramUsage: 0
    property real swapUsage: 0
    property real uploadSpeed: 0
    property real downloadSpeed: 0

    property real prevCpuIdle: 0
    property real prevCpuTotal: 0

    property real prevRxBytes: 0
    property real prevTxBytes: 0
    property real lastNetTime: 0

    Plasma5.DataSource {
        id: cpuSource
        engine: "executable"
        connectedSources: ["grep -m1 '^cpu ' /proc/stat"]
        interval: 2000
        onNewData: (sourceName, data) => {
            let parts = (data.stdout || "").trim().split(/\s+/);
            if (parts.length >= 5) {
                let idle = parseFloat(parts[4]);
                let total = 0;
                for (let i = 1; i < parts.length; i++) total += parseFloat(parts[i]);
                if (root.prevCpuTotal > 0) {
                    let diffTotal = total - root.prevCpuTotal;
                    let diffIdle = idle - root.prevCpuIdle;
                    root.cpuUsage = diffTotal > 0 ? (1 - diffIdle / diffTotal) * 100 : 0;
                }
                root.prevCpuIdle = idle;
                root.prevCpuTotal = total;
            }
        }
    }

    Plasma5.DataSource {
        id: memSource
        engine: "executable"
        connectedSources: ["free -b"]
        interval: 2000
        onNewData: (sourceName, data) => {
            let lines = (data.stdout || "").split('\n');
            for (let line of lines) {
                let parts = line.trim().split(/\s+/);
                if (parts[0] === "Mem:" && parts.length >= 3) {
                    let total = parseFloat(parts[1]);
                    let used = parseFloat(parts[2]);
                    root.ramUsage = total > 0 ? (used / total) * 100 : 0;
                }
                if (parts[0] === "Swap:" && parts.length >= 3) {
                    let total = parseFloat(parts[1]);
                    let used = parseFloat(parts[2]);
                    root.swapUsage = total > 0 ? (used / total) * 100 : 0;
                }
            }
        }
    }

    Plasma5.DataSource {
        id: netSource
        engine: "executable"
        connectedSources: ["cat /proc/net/dev"]
        interval: 2000
        onNewData: (sourceName, data) => {
            let lines = (data.stdout || "").split('\n');
            let rxTotal = 0, txTotal = 0;
            for (let line of lines) {
                line = line.trim();
                if (!line || line.startsWith('Inter') || line.startsWith('face')) continue;
                let colonIdx = line.indexOf(':');
                if (colonIdx === -1) continue;
                let iface = line.substring(0, colonIdx).trim();
                if (iface === 'lo') continue;
                let parts = line.substring(colonIdx + 1).trim().split(/\s+/);
                if (parts.length >= 9) {
                    rxTotal += parseFloat(parts[0]);
                    txTotal += parseFloat(parts[8]);
                }
            }
            let now = Date.now();
            if (root.lastNetTime > 0) {
                let elapsed = (now - root.lastNetTime) / 1000;
                root.downloadSpeed = elapsed > 0 ? (rxTotal - root.prevRxBytes) / elapsed : 0;
                root.uploadSpeed = elapsed > 0 ? (txTotal - root.prevTxBytes) / elapsed : 0;
            }
            root.prevRxBytes = rxTotal;
            root.prevTxBytes = txTotal;
            root.lastNetTime = now;
        }
    }

    function formatSpeed(bytesPerSec) {
        if (bytesPerSec < 1024)
            return bytesPerSec.toFixed(0) + " B";
        else if (bytesPerSec < 1024 * 1024)
            return (bytesPerSec / 1024).toFixed(1) + " kB";
        else
            return (bytesPerSec / (1024 * 1024)).toFixed(1) + " MB";
    }

    fullRepresentation: RowLayout {
        id: row
        spacing: Kirigami.Units.mediumSpacing

        // CPU
        PlasmaComponents.Label {
            text: "CPU: " + Math.round(root.cpuUsage) + "%"
            font.pixelSize: Kirigami.Theme.smallFont.pixelSize
            font.bold: true
        }

        // RAM
        PlasmaComponents.Label {
            text: "RAM: " + Math.round(root.ramUsage) + "%"
            font.pixelSize: Kirigami.Theme.smallFont.pixelSize
            font.bold: true
        }

        // Swap
        PlasmaComponents.Label {
            text: "SWAP: " + Math.round(root.swapUsage) + "%"
            font.pixelSize: Kirigami.Theme.smallFont.pixelSize
            font.bold: true
        }

        // Upload
        RowLayout {
            spacing: Kirigami.Units.smallSpacing
            Kirigami.Icon {
                source: "arrow-up"
                Layout.preferredWidth: Kirigami.Units.iconSizes.small
                Layout.preferredHeight: Kirigami.Units.iconSizes.small
            }
            PlasmaComponents.Label {
                text: formatSpeed(root.uploadSpeed)
                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                font.bold: true
            }
        }

        // Download
        RowLayout {
            spacing: Kirigami.Units.smallSpacing
            Kirigami.Icon {
                source: "arrow-down"
                Layout.preferredWidth: Kirigami.Units.iconSizes.small
                Layout.preferredHeight: Kirigami.Units.iconSizes.small
            }
            PlasmaComponents.Label {
                text: formatSpeed(root.downloadSpeed)
                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                font.bold: true
            }
        }
    }
}
