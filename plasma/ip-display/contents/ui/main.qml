import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as Plasma5
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    preferredRepresentation: compactRepresentation

    property string localIp: "..."
    property string publicIp: "..."

    Plasma5.DataSource {
        id: localIpSource
        engine: "executable"
        connectedSources: ["ip -4 route get 1.1.1.1 | grep -oP 'src \\K[\\d.]+'"]
        interval: 30000
        onNewData: (sourceName, data) => {
            let out = (data.stdout || "").trim();
            root.localIp = out || "N/A";
        }
    }

    Plasma5.DataSource {
        id: publicIpSource
        engine: "executable"
        connectedSources: ["curl -s --max-time 5 https://api.ipify.org"]
        interval: 120000
        onNewData: (sourceName, data) => {
            let out = (data.stdout || "").trim();
            root.publicIp = out || "N/A";
        }
    }

    function refreshIps() {
        localIpSource.connectSource(localIpSource.connectedSources[0]);
        publicIpSource.connectSource(publicIpSource.connectedSources[0]);
    }

    compactRepresentation: RowLayout {
        id: compactRow
        spacing: Kirigami.Units.smallSpacing

        Kirigami.Icon {
            source: "network-wired"
            Layout.preferredWidth: Kirigami.Units.iconSizes.small
            Layout.preferredHeight: Kirigami.Units.iconSizes.small
        }
        PlasmaComponents.Label {
            text: root.localIp + " | " + root.publicIp
            font.pixelSize: Kirigami.Theme.smallFont.pixelSize
            font.bold: true
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
            onClicked: root.refreshIps()
        }
    }

    fullRepresentation: ColumnLayout {
        spacing: Kirigami.Units.mediumSpacing
        Layout.preferredWidth: Kirigami.Units.gridUnit * 14
        Layout.margins: Kirigami.Units.largeSpacing

        PlasmaComponents.Label {
            text: "IP Addresses"
            font.bold: true
            font.pixelSize: Kirigami.Theme.defaultFont.pixelSize * 1.1
        }

        Kirigami.Separator {
            Layout.fillWidth: true
        }

        RowLayout {
            spacing: Kirigami.Units.mediumSpacing
            Kirigami.Icon {
                source: "network-wired"
                Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
            }
            ColumnLayout {
                spacing: 0
                PlasmaComponents.Label {
                    text: "Local"
                    font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                    opacity: 0.7
                }
                PlasmaComponents.Label {
                    text: root.localIp
                    font.bold: true
                    font.family: "monospace"
                }
            }
        }

        RowLayout {
            spacing: Kirigami.Units.mediumSpacing
            Kirigami.Icon {
                source: "internet-services"
                Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
            }
            ColumnLayout {
                spacing: 0
                PlasmaComponents.Label {
                    text: "Public"
                    font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                    opacity: 0.7
                }
                PlasmaComponents.Label {
                    text: root.publicIp
                    font.bold: true
                    font.family: "monospace"
                }
            }
        }

        PlasmaComponents.Button {
            text: "Refresh"
            icon.name: "view-refresh"
            Layout.alignment: Qt.AlignHCenter
            onClicked: root.refreshIps()
        }
    }
}
