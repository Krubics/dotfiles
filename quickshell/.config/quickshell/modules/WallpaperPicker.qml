pragma ComponentBehavior: Bound
import Quickshell
import QtQuick.Layouts 6.0
import QtQuick
import Quickshell.Hyprland
import Qt.labs.folderlistmodel
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Io
import "../components"

PanelWindow {
    id: root
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    implicitHeight: rectangle.implicitHeight
    implicitWidth: rectangle.implicitWidth
    WlrLayershell.namespace: "wallpaper-picker"
    color: "transparent"

    property string wallpaperDir: "/home/krubics/.config/hypr/wallpapers"
    property string screenshotDir: "/home/krubics/.config/hypr/screenshots"

    Process {
        id: setWallpaper
    }

    WrapperRectangle {
        id: rectangle
        anchors.centerIn: parent
        radius: 30
        margin: 20
        color: Qt.rgba(0.05, 0.05, 0.05, 0.05)

        focus: true
        Component.onCompleted: forceActiveFocus()

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Left) {
                wallpaperList.decrementCurrentIndex();
            } else if (event.key === Qt.Key_Right) {
                wallpaperList.incrementCurrentIndex();
            } else if (event.key === Qt.Key_Return) {
                const wallpaperFilePath = wallpaperFiles.get(wallpaperList.currentIndex % wallpaperFiles.count, "filePath");
                setWallpaper.exec(["/home/krubics/.config/hypr/scripts/set-wallpaper.lua", wallpaperFilePath]);
                
                event.accepted = true;
            }
        }

        ListView {
            id: wallpaperList
            implicitHeight: 300
            implicitWidth: 500
            model: 500
            clip: true
            spacing: 30

            currentIndex: 50

            readonly property real cardWidth: width / 3 - 20
            preferredHighlightBegin: width / 2 - cardWidth / 2
            preferredHighlightEnd: width / 2 + cardWidth / 2

            highlightRangeMode: ListView.ApplyRange
            highlightMoveVelocity: -1
            highlightMoveDuration: 300

            orientation: ListView.Horizontal
            snapMode: ListView.SnapOneItem

            Component.onCompleted: {
                positionViewAtIndex(currentIndex, ListView.SnapPosition);
            }

            delegate: ClippingRectangle {
                id: wallpaperCard

                required property int index

                height: ListView.view.height
                width: wallpaperList.cardWidth // To allow for spacing between the tags
                opacity: ListView.isCurrentItem ? 1 : 0.8
                scale: ListView.isCurrentItem ? 1 : 0.8
                radius: 10

                MediaDisplay {
                    id: wallpaperImage
                    anchors.fill: parent
                    source: wallpaperFiles.get(wallpaperCard.index % wallpaperFiles.count, "fileUrl")
                }

                Behavior on scale {
                    NumberAnimation {
                        duration: 300
                        easing.type: Easing.OutCubic
                    }
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: 160
                    }
                }
            }
        }
    }
    FolderListModel {
        id: wallpaperFiles
        folder: "file://" + root.wallpaperDir
        nameFilters: ["*"]
        sortField: FolderListModel.Name
    }
}
