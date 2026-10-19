import Quickshell
import QtQuick
import QtQuick.Layouts


import Quickshell.I3


import Quickshell.Widgets
import Quickshell.Services.SystemTray
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire


import "StatusBarWidgets"


Scope {
    id: root
    property var theme: DefaultTheme {}
    property string font: "JetBrainsMono Nerd Font"
    property bool barVisible: true

    // For Time & Date
    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }
    
    // MPRIS active player
    property var activePlayer: {
        const players = Mpris.players.values;
        if (!players || players.length === 0) return null;
        for (const p of players) {
            if (p.playbackState === MprisPlaybackState.Playing) return p;
        }
        return players[0];
    }

    IpcHandler {
        target: "bar"
        function toggle(): void { root.barVisible = !root.barVisible; }
    }

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }

    // Brightness state
    property real brightnessValue: 0
    property real brightnessMax: 1

    FileView {
        id: brightnessFile
        path: ""
        watchChanges: true
        onFileChanged: brightnessReadProc.running = true
    }

    Process {
        id: brightnessReadProc
        command: ["brightnessctl", "get"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const val = parseInt(text.trim());
                if (!isNaN(val) && root.brightnessMax > 0)
                    root.brightnessValue = val / root.brightnessMax;
            }
        }
    }

    Process {
        id: brightnessSetProc
        running: false
    }

    Process {
        id: backlightDiscovery
        command: ["sh", "-c", "p=$(ls -d /sys/class/backlight/*/brightness 2>/dev/null | head -1); [ -n \"$p\" ] && echo \"$p\" && cat \"${p%brightness}max_brightness\""]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n");
                if (lines.length >= 2) {
                    const max = parseInt(lines[1]);
                    if (!isNaN(max) && max > 0) root.brightnessMax = max;
                    brightnessFile.path = lines[0];
                    brightnessReadProc.running = true;
                }
            }
        }
    }

    Variants {
        model: Quickshell.screens

        //        Rectangle {
        //            id: bgRectangle
        //            color: root.theme.bgBase
        //            height: rootPanel.height+50
        //            width: rootPanel.width+50
        //            radius: 12
        //            anchors.fill: rootPanel
        //        }
        
        PanelWindow {
            id: rootPanel
            required property var modelData
            screen: modelData
            visible: root.barVisible
            
            anchors {
                top: false
                bottom: true
                left: true
                right: true
            }

            margins {
                top: -5
                bottom: 5
                left: 20
                right: 20
            }
            
            implicitHeight: 32
            color: root.theme.bgBase

            Item {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10

                // Left section: Time + Workspaces + Now Playing
                Row {
                    id: leftSection
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    // Time
                    Rectangle {
                        height: 24
                        width: timeSection.width + 16
                        radius: 12
                        color: root.theme.bgSurface

                        Row {
                            id: timeSection
                            anchors.centerIn: parent
                            spacing: 8

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: Qt.formatDateTime(clock.date, "hh:mm ap")
                                color: root.theme.textPrimary
                                font.pixelSize: 12
                                font.family: root.font
                            }

                        }
                    }

                    Rectangle {
                        height: 24
                        width: dateSection.width + 16
                        radius: 12
                        color: root.theme.bgSurface
                        
                        Row {
                            id: dateSection
                            anchors.centerIn: parent
                            spacing: 8
                            
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: Qt.formatDateTime(clock.date, "dd MM yyyy")
                                color: root.theme.textSecondary
                                font.pixelSize: 12
                                font.family: root.font
                            }
                        }
                    }

                    // Workspaces
                    Row {
                        spacing: 4

                        Repeater {
                            model: I3.workspaces

                            Rectangle {
                                id: wsPill
                                required property var modelData
                                property bool urgentBlink: false

                                Accessible.role: Accessible.Button
                                Accessible.name: "Workspace " + modelData.id + (modelData.focused ? ", active" : "") + (modelData.urgent ? ", urgent" : "")

                                width: modelData.focused ? 32 : 24
                                height: 24
                                radius: 12
                                color: modelData.focused ? root.theme.accentPrimary :
                                    modelData.urgent && urgentBlink ? root.theme.accentRed : root.theme.bgSurface

                                Behavior on color {
                                    ColorAnimation { duration: 150 }
                                }

                                SequentialAnimation {
                                    loops: Animation.Infinite
                                    running: wsPill.modelData.urgent && !wsPill.modelData.focused

                                    PropertyAction { target: wsPill; property: "urgentBlink"; value: true }
                                    PauseAnimation { duration: 500 }
                                    PropertyAction { target: wsPill; property: "urgentBlink"; value: false }
                                    PauseAnimation { duration: 500 }

                                    onStopped: wsPill.urgentBlink = false
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: wsPill.modelData.name
                                    color: wsPill.modelData.focused ? root.theme.bgBase : root.theme.textPrimary
                                    font.pixelSize: 11
                                    font.family: root.font
                                    font.bold: wsPill.modelData.focused
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: wsPill.modelData.activate()
                                }

                                Behavior on width {
                                    NumberAnimation { duration: 150 }
                                }
                            }
                        }
                    }

                    // Now Playing
                    Rectangle {
                        height: 24
                        width: nowPlayingContent.width + 16
                        radius: 12
                        color: root.theme.bgSurface
                        visible: root.activePlayer !== null

                        Accessible.role: Accessible.Button
                        Accessible.name: {
                            if (!root.activePlayer) return "No media";
                            const artist = root.activePlayer.trackArtist || "";
                            const title = root.activePlayer.trackTitle || "";
                            return "Now playing: " + (artist ? artist + " - " : "") + title;
                        }

                        Row {
                            id: nowPlayingContent
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 8
                            spacing: 6

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.activePlayer && root.activePlayer.isPlaying ? "󰏤" : "󰐊"
                                color: root.theme.accentPrimary
                                font.pixelSize: 14
                                font.family: root.font
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: {
                                    if (!root.activePlayer) return "";
                                    const artist = root.activePlayer.trackArtist || "";
                                    const title = root.activePlayer.trackTitle || "";
                                    return artist ? artist + " - " + title : title;
                                }
                                color: root.theme.textPrimary
                                font.pixelSize: 11
                                font.family: root.font
                                elide: Text.ElideRight
                                width: Math.min(implicitWidth, 200)
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.activePlayer.togglePlaying()
                        }
                    }
                }

                // Center section: Window Title (truly centered in bar)
                Item {
                    anchors.centerIn: parent
                    height: parent.height
                    width: Math.max(0, parent.width - 2 * Math.max(leftSection.width, rightSection.width) - 32)

                    Text {
                        Accessible.role: Accessible.StaticText
                        Accessible.name: "Active window: " + text
                        text: Hyprland.activeToplevel ? Hyprland.activeToplevel.title : ""
                        color: root.theme.textPrimary
                        font.pixelSize: 13
                        font.family: root.font
                        elide: Text.ElideRight
                        width: Math.min(implicitWidth, parent.width)
                        anchors.centerIn: parent
                    }
                }

                // Right section: System Info + System Tray
                Row {
                    id: rightSection
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    // Volume
                    Rectangle {
                        id: volPill
                        height: 24
                        width: volContent.width + 12
                        radius: 12
                        color: root.theme.bgSurface

                        Accessible.role: Accessible.Button
                        Accessible.name: {
                            const sink = Pipewire.defaultAudioSink;
                            if (!sink || !sink.audio) return "Volume";
                            if (sink.audio.muted) return "Volume: muted";
                            return "Volume: " + Math.round(sink.audio.volume * 100) + "%";
                        }

                        Row {
                            id: volContent
                            anchors.centerIn: parent
                            spacing: 6

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: {
                                    const sink = Pipewire.defaultAudioSink;
                                    if (!sink || !sink.audio || sink.audio.muted || sink.audio.volume <= 0) return "󰖁";
                                    if (sink.audio.volume < 0.33) return "󰕿";
                                    if (sink.audio.volume < 0.66) return "󰖀";
                                    return "󰕾";
                                }
                                color: {
                                    const sink = Pipewire.defaultAudioSink;
                                    if (!sink || !sink.audio || sink.audio.muted) return root.theme.textMuted;
                                    return root.theme.accentPrimary;
                                }
                                font.pixelSize: 14
                                font.family: root.font
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: {
                                    const sink = Pipewire.defaultAudioSink;
                                    if (!sink || !sink.audio) return "–";
                                    if (sink.audio.muted) return "Mute";
                                    return Math.round(sink.audio.volume * 100) + "%";
                                }
                                color: root.theme.textPrimary
                                font.pixelSize: 11
                                font.family: root.font
                            }
                        }

                        MouseArea {
                            id: volMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                            onClicked: (mouse) => {
                                if (mouse.button === Qt.LeftButton) {
                                    mixerPopup.visible = !mixerPopup.visible;
                                } else {
                                    const sink = Pipewire.defaultAudioSink;
                                    if (sink && sink.audio) sink.audio.muted = !sink.audio.muted;
                                }
                            }
                            onWheel: (wheel) => {
                                const sink = Pipewire.defaultAudioSink;
                                if (!sink || !sink.audio) return;
                                const delta = wheel.angleDelta.y > 0 ? 0.05 : -0.05;
                                sink.audio.volume = Math.max(0, Math.min(1.5, sink.audio.volume + delta));
                            }
                        }

                        // Tracks the apps playing into the default sink
                        PwNodeLinkTracker {
                            id: linkTracker
                            node: Pipewire.defaultAudioSink
                        }

                        // Mixer popup (opens upward since the bar is at the bottom)
                        PopupWindow {
                            id: mixerPopup
                            visible: false
                            color: "transparent"

                            anchor.window: rootPanel
                            anchor.edges: Edges.Top | Edges.Right
                            anchor.gravity: Edges.Top | Edges.Left
                            anchor.adjustment: PopupAdjustment.Slide
                            anchor.onAnchoring: {
                                anchor.rect = rootPanel.contentItem.mapFromItem(
                                    volPill, 0, -6, volPill.width, volPill.height);
                            }

                            implicitWidth: mixerBox.implicitWidth
                            implicitHeight: mixerBox.implicitHeight

                            // Auto-close shortly after the mouse leaves both pill and popup
                            Timer {
                                id: closeTimer
                                interval: 600
                                running: mixerPopup.visible && !volMouse.containsMouse && !popupHover.hovered
                                onTriggered: mixerPopup.visible = false
                            }

                            Rectangle {
                                id: mixerBox
                                anchors.fill: parent
                                implicitWidth: mixerCol.implicitWidth + 24
                                implicitHeight: mixerCol.implicitHeight + 24
                                radius: 12
                                color: root.theme.bgBase
                                border.color: root.theme.bgSurface
                                border.width: 2

                                HoverHandler { id: popupHover }

                                ColumnLayout {
                                    id: mixerCol
                                    anchors.centerIn: parent
                                    spacing: 8

                                    // Master
                                    MixerEntry {
                                        node: Pipewire.defaultAudioSink
                                        theme: root.theme
                                        font: root.font
                                        labelOverride: "Master"
                                        maxVolume: 1.5
                                        visible: Pipewire.defaultAudioSink !== null
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true
                                        height: 1
                                        color: root.theme.bgSurface
                                        visible: linkTracker.linkGroups.length > 0
                                    }

                                    // Per-app streams
                                    Repeater {
                                        model: linkTracker.linkGroups

                                        MixerEntry {
                                            required property PwLinkGroup modelData
                                            node: modelData.source
                                            theme: root.theme
                                            font: root.font
                                        }
                                    }

                                    Text {
                                        visible: linkTracker.linkGroups.length === 0
                                        text: "No apps playing audio"
                                        color: root.theme.textMuted
                                        font.pixelSize: 11
                                        font.family: root.font
                                    }
                                }
                            }
                        }
                    }

                    // Brightness
                    Rectangle {
                        height: 24
                        width: brightContent.width + 12
                        radius: 12
                        color: root.theme.bgSurface
                        visible: brightnessFile.path !== ""

                        Accessible.role: Accessible.StaticText
                        Accessible.name: "Brightness: " + Math.round(root.brightnessValue * 100) + "%"

                        Row {
                            id: brightContent
                            anchors.centerIn: parent
                            spacing: 6

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "󰃠"
                                color: root.theme.accentOrange
                                font.pixelSize: 14
                                font.family: root.font
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: Math.round(root.brightnessValue * 100) + "%"
                                color: root.theme.textPrimary
                                font.pixelSize: 11
                                font.family: root.font
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onWheel: (wheel) => {
                                brightnessSetProc.command = wheel.angleDelta.y > 0
                                    ? ["brightnessctl", "set", "5%+"]
                                    : ["brightnessctl", "set", "5%-"];
                                brightnessSetProc.running = true;
                            }
                        }
                    }

                    // System Info
                    Row {
                        id: sysInfo

                        readonly property color batteryColor: {
                            if (SystemInfo.batteryCharging) return root.theme.accentGreen;
                            if (SystemInfo.batteryLevelRaw > 20) return root.theme.batteryGood;
                            if (SystemInfo.batteryLevelRaw > 10) return root.theme.batteryWarning;
                            return root.theme.batteryCritical;
                        }

                        spacing: 4

                        // CPU
                        Rectangle {
                            height: 24
                            width: cpuContent.width + 12
                            radius: 12
                            color: root.theme.bgSurface
                            Accessible.role: Accessible.StaticText
                            Accessible.name: "CPU: " + SystemInfo.cpuUsage

                            Row {
                                id: cpuContent
                                anchors.centerIn: parent
                                spacing: 6

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "󰻠"
                                    //font.size: 15
                                    color: root.theme.accentOrange
                                    font.pixelSize: 14
                                    font.family: root.font
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: SystemInfo.cpuUsage
                                    color: root.theme.textPrimary
                                    font.pixelSize: 11
                                    font.family: root.font
                                }
                            }
                        }

                        // Temperature
                        Rectangle {
                            height: 24
                            width: tempContent.width + 12
                            radius: 12
                            color: root.theme.bgSurface
                            Accessible.role: Accessible.StaticText
                            Accessible.name: "Temperature: " + SystemInfo.temperature

                            Row {
                                id: tempContent
                                anchors.centerIn: parent
                                spacing: 6

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "󰔏"
                                    color: root.theme.accentRed
                                    font.pixelSize: 14
                                    font.family: root.font
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: SystemInfo.temperature
                                    color: root.theme.textPrimary
                                    font.pixelSize: 11
                                    font.family: root.font
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
