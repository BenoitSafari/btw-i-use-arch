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

    property real prevUpBytes: -1
    property real prevDownBytes: -1
    property real prevTime: 0

    Plasma5.DataSource {
        id: cpuSource
        engine: "systemmonitor"
        connectedSources: ["cpu/all/usage"]
        interval: 2000
        onNewData: (sourceName, data) => {
            if (sourceName === "cpu/all/usage") {
                root.cpuUsage = data.value || 0;
            }
        }
    }

    Plasma5.DataSource {
        id: memSource
        engine: "systemmonitor"
        connectedSources: [
            "memory/physical/used",
            "memory/physical/total",
            "memory/swap/used",
            "memory/swap/total"
        ]
        interval: 2000
        onNewData: (sourceName, data) => {
            if (sourceName === "memory/physical/used") {
                let total = memSource.data["memory/physical/total"]
                    ? memSource.data["memory/physical/total"].value : 1;
                root.ramUsage = total > 0 ? (data.value / total) * 100 : 0;
            }
            if (sourceName === "memory/swap/used") {
                let total = memSource.data["memory/swap/total"]
                    ? memSource.data["memory/swap/total"].value : 1;
                root.swapUsage = total > 0 ? (data.value / total) * 100 : 0;
            }
        }
    }

    Plasma5.DataSource {
        id: netSource
        engine: "systemmonitor"
        connectedSources: [
            "network/all/upload",
            "network/all/download"
        ]
        interval: 2000
        onNewData: (sourceName, data) => {
            if (sourceName === "network/all/upload") {
                root.uploadSpeed = data.value || 0;
            }
            if (sourceName === "network/all/download") {
                root.downloadSpeed = data.value || 0;
            }
        }
    }

    function formatSpeed(bytesPerSec) {
        if (bytesPerSec < 1024)
            return bytesPerSec.toFixed(1) + " B";
        else if (bytesPerSec < 1024 * 1024)
            return (bytesPerSec / 1024).toFixed(1) + " kB";
        else
            return (bytesPerSec / (1024 * 1024)).toFixed(1) + " MB";
    }

    fullRepresentation: RowLayout {
        id: row
        spacing: Kirigami.Units.mediumSpacing

        // CPU
        RowLayout {
            spacing: Kirigami.Units.smallSpacing
            Kirigami.Icon {
                source: "cpu"
                Layout.preferredWidth: Kirigami.Units.iconSizes.small
                Layout.preferredHeight: Kirigami.Units.iconSizes.small
            }
            PlasmaComponents.Label {
                text: Math.round(root.cpuUsage) + "%"
                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
            }
        }

        // RAM
        RowLayout {
            spacing: Kirigami.Units.smallSpacing
            Kirigami.Icon {
                source: "memory"
                Layout.preferredWidth: Kirigami.Units.iconSizes.small
                Layout.preferredHeight: Kirigami.Units.iconSizes.small
            }
            PlasmaComponents.Label {
                text: Math.round(root.ramUsage) + "%"
                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
            }
        }

        // Swap
        RowLayout {
            spacing: Kirigami.Units.smallSpacing
            Kirigami.Icon {
                source: "exchange-positions"
                Layout.preferredWidth: Kirigami.Units.iconSizes.small
                Layout.preferredHeight: Kirigami.Units.iconSizes.small
            }
            PlasmaComponents.Label {
                text: Math.round(root.swapUsage) + "%"
                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
            }
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
            }
        }
    }
}
