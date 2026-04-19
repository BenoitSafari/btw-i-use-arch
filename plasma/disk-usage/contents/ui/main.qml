import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as Plasma5
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    property var disks: []

    preferredRepresentation: compactRepresentation

    Plasma5.DataSource {
        id: lsblkSource
        engine: "executable"
        connectedSources: ["lsblk --json -b -o NAME,SIZE,TYPE,FSSIZE,FSUSED,FSAVAIL,FSUSE%,MOUNTPOINTS"]
        interval: 30000
        onNewData: (sourceName, data) => {
            try {
                const parsed = JSON.parse(data.stdout || "{}");
                root.disks = (parsed.blockdevices || []).filter(d => d.type === "disk");
            } catch (e) {
                root.disks = [];
            }
        }
    }

    function formatBytes(n) {
        if (n === null || n === undefined || isNaN(n)) return "-";
        const v = Number(n);
        if (v < 1024) return v.toFixed(0) + " B";
        if (v < 1024 * 1024) return (v / 1024).toFixed(1) + " KB";
        if (v < 1024 * 1024 * 1024) return (v / (1024 * 1024)).toFixed(1) + " MB";
        if (v < 1024 * 1024 * 1024 * 1024) return (v / (1024 * 1024 * 1024)).toFixed(1) + " GB";
        return (v / (1024 * 1024 * 1024 * 1024)).toFixed(2) + " TB";
    }

    function diskUsedBytes(disk) {
        let total = 0;
        const kids = disk.children || [];
        for (let i = 0; i < kids.length; i++) {
            const u = kids[i].fsused;
            if (u !== null && u !== undefined) total += Number(u);
        }
        return total;
    }

    function diskUsedPct(disk) {
        if (!disk.size) return 0;
        return diskUsedBytes(disk) / Number(disk.size);
    }

    function firstMountpoint(part) {
        const mps = part.mountpoints || [];
        for (let i = 0; i < mps.length; i++) {
            if (mps[i] && mps[i] !== "[SWAP]") return mps[i];
        }
        return "";
    }

    function isSwap(part) {
        return (part.mountpoints || []).indexOf("[SWAP]") !== -1;
    }

    function treeChar(index, total) {
        return index === total - 1 ? "└─" : "├─";
    }

    function parsePct(str) {
        if (!str) return 0;
        return parseFloat(String(str).replace("%", "")) / 100;
    }

    compactRepresentation: Item {
        Layout.preferredWidth: Kirigami.Units.iconSizes.small
        Layout.preferredHeight: Kirigami.Units.iconSizes.small

        Kirigami.Icon {
            anchors.fill: parent
            source: "drive-harddisk"
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.expanded = !root.expanded
        }
    }

    fullRepresentation: ColumnLayout {
        Layout.preferredWidth: Kirigami.Units.gridUnit * 32
        Layout.minimumWidth: Kirigami.Units.gridUnit * 28
        spacing: Kirigami.Units.largeSpacing

        PlasmaExtras.Heading {
            text: "Disk Usage"
            level: 3
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.smallSpacing
            horizontalAlignment: Text.AlignHCenter
        }

        Repeater {
            model: root.disks

            delegate: ColumnLayout {
                id: diskBlock
                required property var modelData
                required property int index

                Layout.fillWidth: true
                Layout.leftMargin: Kirigami.Units.largeSpacing
                Layout.rightMargin: Kirigami.Units.largeSpacing
                spacing: Kirigami.Units.smallSpacing

                Kirigami.Separator {
                    Layout.fillWidth: true
                    visible: diskBlock.index > 0
                    Layout.bottomMargin: Kirigami.Units.smallSpacing
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 5
                    radius: 2
                    color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.15)
                    Rectangle {
                        width: parent.width * Math.min(1, Math.max(0, root.diskUsedPct(diskBlock.modelData)))
                        height: parent.height
                        radius: parent.radius
                        color: root.diskUsedPct(diskBlock.modelData) > 0.8
                               ? Kirigami.Theme.negativeTextColor
                               : Kirigami.Theme.highlightColor
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    PlasmaComponents.Label {
                        text: diskBlock.modelData.name
                        font.bold: true
                        Layout.fillWidth: true
                    }
                    PlasmaComponents.Label {
                        text: root.formatBytes(root.diskUsedBytes(diskBlock.modelData))
                              + " / " + root.formatBytes(diskBlock.modelData.size)
                              + " — " + Math.round(root.diskUsedPct(diskBlock.modelData) * 100) + "%"
                        font.bold: true
                        font.family: "monospace"
                    }
                }

                Repeater {
                    model: diskBlock.modelData.children || []

                    delegate: RowLayout {
                        id: partRow
                        required property var modelData
                        required property int index

                        property int partTotal: (diskBlock.modelData.children || []).length
                        property bool mounted: modelData.fssize !== null && modelData.fssize !== undefined
                        property bool swap: root.isSwap(modelData)

                        Layout.fillWidth: true
                        spacing: Kirigami.Units.smallSpacing

                        PlasmaComponents.Label {
                            text: root.treeChar(partRow.index, partRow.partTotal) + " " + partRow.modelData.name
                            font.family: "monospace"
                            Layout.preferredWidth: Kirigami.Units.gridUnit * 11
                        }

                        PlasmaComponents.Label {
                            text: partRow.mounted
                                  ? (root.formatBytes(partRow.modelData.fsused) + "/" + root.formatBytes(partRow.modelData.fssize))
                                  : ("-/" + root.formatBytes(partRow.modelData.size))
                            font.family: "monospace"
                            horizontalAlignment: Text.AlignRight
                            Layout.preferredWidth: Kirigami.Units.gridUnit * 10
                        }

                        Item {
                            Layout.preferredWidth: Kirigami.Units.gridUnit * 5
                            Layout.preferredHeight: 5

                            Rectangle {
                                visible: partRow.mounted && !partRow.swap
                                anchors.fill: parent
                                radius: 2
                                color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.15)
                                Rectangle {
                                    property real ratio: root.parsePct(partRow.modelData["fsuse%"])
                                    width: parent.width * Math.min(1, Math.max(0, ratio))
                                    height: parent.height
                                    radius: parent.radius
                                    color: ratio > 0.8
                                           ? Kirigami.Theme.negativeTextColor
                                           : Kirigami.Theme.highlightColor
                                }
                            }
                        }

                        PlasmaComponents.Label {
                            text: partRow.swap ? "[SWAP]" : root.firstMountpoint(partRow.modelData)
                            opacity: 0.7
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }
    }
}
