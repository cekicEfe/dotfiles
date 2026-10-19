import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire

RowLayout {
    id: entry

    required property PwNode node
    required property var theme
    property string font: "JetBrainsMono Nerd Font"
    property string labelOverride: ""
    property real maxVolume: 1.0

    spacing: 8

    // Needed so node.audio is bound and usable
    PwObjectTracker { objects: [entry.node] }

    readonly property string label: {
        if (labelOverride !== "") return labelOverride;
        if (!node) return "";
        const p = node.properties;
        return p["application.name"] || node.description || node.nickname || node.name;
    }

    // Mute / icon
    Text {
        Layout.preferredWidth: 18
        horizontalAlignment: Text.AlignHCenter
        text: (!entry.node?.audio || entry.node.audio.muted || entry.node.audio.volume <= 0) ? "󰖁" : "󰕾"
        color: (entry.node?.audio?.muted) ? entry.theme.textMuted : entry.theme.accentPrimary
        font.pixelSize: 14
        font.family: entry.font

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: if (entry.node?.audio) entry.node.audio.muted = !entry.node.audio.muted
        }
    }

    // Name
    Text {
        Layout.preferredWidth: 110
        text: entry.label
        color: entry.theme.textPrimary
        font.pixelSize: 11
        font.family: entry.font
        elide: Text.ElideRight
    }

    // Slider
    Item {
        id: slider
        Layout.preferredWidth: 140
        Layout.preferredHeight: 18

        readonly property real value: entry.node?.audio ? entry.node.audio.volume : 0
        readonly property real ratio: Math.max(0, Math.min(1, value / entry.maxVolume))

        function setFromX(x) {
            if (!entry.node?.audio) return;
            const r = Math.max(0, Math.min(1, x / width));
            entry.node.audio.volume = r * entry.maxVolume;
        }

        Rectangle {
            id: track
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: 4
            radius: 2
            color: entry.theme.bgBase

            Rectangle {
                width: parent.width * slider.ratio
                height: parent.height
                radius: 2
                color: entry.node?.audio?.muted ? entry.theme.textMuted : entry.theme.accentPrimary
            }
        }

        Rectangle {
            width: 12; height: 12; radius: 6
            anchors.verticalCenter: parent.verticalCenter
            x: slider.ratio * (slider.width - width)
            color: entry.theme.textPrimary
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onPressed: (m) => slider.setFromX(m.x)
            onPositionChanged: (m) => { if (pressed) slider.setFromX(m.x) }
            onWheel: (w) => {
                if (!entry.node?.audio) return;
                const d = w.angleDelta.y > 0 ? 0.05 : -0.05;
                entry.node.audio.volume = Math.max(0, Math.min(entry.maxVolume, entry.node.audio.volume + d));
            }
        }
    }

    // Percentage
    Text {
        Layout.preferredWidth: 34
        horizontalAlignment: Text.AlignRight
        text: entry.node?.audio ? Math.round(entry.node.audio.volume * 100) + "%" : "–"
        color: entry.theme.textSecondary
        font.pixelSize: 11
        font.family: entry.font
    }
}
