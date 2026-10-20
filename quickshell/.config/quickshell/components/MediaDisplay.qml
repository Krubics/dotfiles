// MediaDisplay.qml
import QtQuick
import QtMultimedia

Item {
    id: root

    required property url source
    property bool playing: true
    property bool muted: true

    readonly property string sourceString: source.toString().toLowerCase()

    readonly property bool isVideo: sourceString.endsWith(".mp4") || sourceString.endsWith(".webm") || sourceString.endsWith(".mkv") || sourceString.endsWith(".mov") || sourceString.endsWith(".avi")

    Image {
        anchors.fill: parent

        visible: !root.isVideo
        source: visible ? root.source : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
    }

    Video {
        anchors.fill: parent

        visible: root.isVideo
        source: visible ? root.source : ""

        autoPlay: root.playing
        muted: root.muted
        loops: MediaPlayer.Infinite
        fillMode: VideoOutput.PreserveAspectCrop
    }
}
