import QtQuick
import QtMultimedia


Item {
    id: prettyPlayer
    property string videoSource: "assets/samples/sample.mp4"
    property real videoPlaySpeed: 1.0
    implicitHeight: 300
    implicitWidth: 200

    MediaPlayer {
        id: player
        source: videoSource
        loops: MediaPlayer.Infinite
        playbackRate: videoPlaySpeed  // 0.5 = half speed, 0.75 = 75% speed
        videoOutput: output
        audioOutput: AudioOutput { muted: true }
        Component.onCompleted: play()
    }

    VideoOutput {
        id: output
        anchors.fill: parent
        fillMode: VideoOutput.PreserveAspectCrop
    }
}
