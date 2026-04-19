import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as Plasma5
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    property var volumes: []
    property string hostLabel: ""
    property string errorMsg: ""

    readonly property string scriptPath: Qt.resolvedUrl("../scripts/fetch-nas-disk.sh").toString().replace("file://", "")

    preferredRepresentation: compactRepresentation

    Plasma5.DataSource {
        id: nasSource
        engine: "executable"
        connectedSources: [root.scriptPath]
        interval: 60000
        onNewData: (sourceName, data) => {
            try {
                const parsed = JSON.parse(data.stdout || "{}");
                root.errorMsg = parsed.error || "";
                root.volumes = parsed.volumes || [];
                root.hostLabel = parsed.host || "";
            } catch (e) {
                root.errorMsg = "parse error: " + e;
                root.volumes = [];
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

    function volRatio(vol) {
        if (!vol || !vol.size) return 0;
        return Number(vol.used) / Number(vol.size);
    }

    compactRepresentation: Item {
        Layout.preferredWidth: Kirigami.Units.iconSizes.small
        Layout.preferredHeight: Kirigami.Units.iconSizes.small

        Kirigami.Icon {
            anchors.fill: parent
            source: "network-server-database"
            opacity: root.errorMsg ? 0.5 : 1.0
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.expanded = !root.expanded
        }
    }

    fullRepresentation: ColumnLayout {
        Layout.preferredWidth: Kirigami.Units.gridUnit * 30
        Layout.minimumWidth: Kirigami.Units.gridUnit * 26
        spacing: Kirigami.Units.largeSpacing

        PlasmaExtras.Heading {
            text: root.hostLabel || "NAS Storage"
            level: 3
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.smallSpacing
            horizontalAlignment: Text.AlignHCenter
        }

        // Error state
        PlasmaComponents.Label {
            visible: root.errorMsg !== ""
            text: root.errorMsg
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.largeSpacing
            Layout.rightMargin: Kirigami.Units.largeSpacing
            wrapMode: Text.WordWrap
            color: Kirigami.Theme.negativeTextColor
        }

        // Empty state (no volumes, no error)
        PlasmaComponents.Label {
            visible: root.errorMsg === "" && root.volumes.length === 0
            text: "No volumes reported"
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            opacity: 0.6
        }

        // Volumes
        Repeater {
            model: root.volumes

            delegate: ColumnLayout {
                id: volBlock
                required property var modelData
                required property int index

                Layout.fillWidth: true
                Layout.leftMargin: Kirigami.Units.largeSpacing
                Layout.rightMargin: Kirigami.Units.largeSpacing
                spacing: Kirigami.Units.smallSpacing

                Kirigami.Separator {
                    Layout.fillWidth: true
                    visible: volBlock.index > 0
                    Layout.bottomMargin: Kirigami.Units.smallSpacing
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 5
                    radius: 2
                    color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.15)
                    Rectangle {
                        property real ratio: root.volRatio(volBlock.modelData)
                        width: parent.width * Math.min(1, Math.max(0, ratio))
                        height: parent.height
                        radius: parent.radius
                        color: ratio > 0.8
                               ? Kirigami.Theme.negativeTextColor
                               : Kirigami.Theme.highlightColor
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    PlasmaComponents.Label {
                        text: volBlock.modelData.name || volBlock.modelData.target
                        font.bold: true
                        Layout.fillWidth: true
                    }
                    PlasmaComponents.Label {
                        text: root.formatBytes(volBlock.modelData.used)
                              + " / " + root.formatBytes(volBlock.modelData.size)
                              + " — " + Math.round(root.volRatio(volBlock.modelData) * 100) + "%"
                        font.bold: true
                        font.family: "monospace"
                    }
                }

                PlasmaComponents.Label {
                    text: volBlock.modelData.target + "    " + root.formatBytes(volBlock.modelData.avail) + " free"
                    opacity: 0.6
                    font.family: "monospace"
                    Layout.fillWidth: true
                }
            }
        }
    }
}
