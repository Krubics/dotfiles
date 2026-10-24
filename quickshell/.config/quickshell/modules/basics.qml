pragma ComponentBehavior: Bound
import Quickshell
import QtQuick.Layouts 6.0
import QtQuick
import Quickshell.Hyprland

PanelWindow {
    id: root
    anchors {
        top: true
    }
    margins {
        top: 10
    }
    property var activeWorkspace: Hyprland.focusedWorkspace.id
    implicitHeight: workspaceBar.implicitHeight
    implicitWidth: workspaceBar.implicitWidth
    color: "transparent"
    Rectangle {
        id: workspaceBar
        radius: 8
        clip: true
        color: "white"
        border.color: "black"
        implicitWidth: rowLayout.implicitWidth + 24
        implicitHeight: rowLayout.implicitHeight + 24
        RowLayout {
            id: rowLayout
            spacing: 8
            anchors.fill: parent
            Repeater {
                id: workspaceRepeater
                model: [1, 2, 3]
                delegate: Item {
                    id: workspaceItem
                    required property int modelData

                    implicitHeight: workspaceText.implicitHeight
                    implicitWidth: 24

                    Layout.fillWidth: true
                    Layout.margins: 4
                    Text {
                        id: workspaceText
                        visible: parent.modelData !== root.activeWorkspace
                        text: parent.modelData
                        color: "black"
                        font.pixelSize: 18
                        anchors.centerIn: parent
                    }
                    Rectangle {
                        color: "lightblue"
                        radius: 4
                        visible: workspaceItem.modelData === root.activeWorkspace
                        implicitHeight: workspaceImage.height + 10
                        implicitWidth: workspaceImage.width + 10
                        anchors.centerIn: parent
                        Image {
                            id: workspaceImage
                            source: "/home/krubics/.config/waybar/assets/pokeball.png"
                            anchors.centerIn: parent
                            height: 24
                            width: 24
                        }
                    }
                }
            }
            Text {
                text: "|"
                color: "black"
                font.pixelSize: 30
            }
        }
    }
}
