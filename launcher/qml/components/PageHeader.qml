// SPDX-License-Identifier: Apache-2.0
// Shared header strip used by every sub-view (Accounts / NewInstance /
// Settings). Back arrow on the left, big title in the middle, optional action
// slot on the right. Auto-collapses the right slot when empty.

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

import BerserkMC.Ui 1.0

Rectangle {
    id: bar
    property string title: ""
    property string subtitle: ""
    property string iconName: ""
    default property alias rightContent: rightSlot.data
    signal back()

    implicitHeight: 64
    color: "transparent"

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 24
        anchors.rightMargin: 24
        spacing: 18

        Rectangle {
            id: backBtn
            implicitWidth: 36; implicitHeight: 36
            radius: Theme.radiusMd
            color: backHover.containsMouse ? Theme.bgElevated : "transparent"
            border.color: backHover.containsMouse ? Theme.border : Theme.borderSubtle
            border.width: 1
            Behavior on color        { ColorAnimation { duration: Theme.durFast } }
            Behavior on border.color { ColorAnimation { duration: Theme.durFast } }
            scale: backHover.pressed ? 0.95 : 1
            Behavior on scale { NumberAnimation { duration: Theme.durFast; easing.type: Easing.OutCubic } }

            Icon {
                anchors.centerIn: parent
                name: "arrow-left"
                color: backHover.containsMouse ? Theme.textPrimary : Theme.textMuted
                size: 18
            }
            MouseArea {
                id: backHover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: bar.back()
            }
        }

        // Optional left-side icon badge
        Rectangle {
            visible: bar.iconName.length > 0
            implicitWidth: 40; implicitHeight: 40
            radius: Theme.radiusMd
            color: Theme.accentSoft
            border.color: Theme.accentRing
            border.width: 1
            Icon {
                anchors.centerIn: parent
                name: bar.iconName
                color: Theme.accentStrong
                size: 20
            }
        }

        Column {
            Layout.fillWidth: true
            spacing: 1

            Text {
                text: bar.title
                color: Theme.textPrimary
                font.family: Theme.fontBody
                font.pointSize: 17
                font.weight: Font.Bold
            }
            Text {
                text: bar.subtitle
                visible: text.length > 0
                color: Theme.textDim
                font.family: Theme.fontBody
                font.pointSize: 10
            }
        }

        Row {
            id: rightSlot
            spacing: 8
        }
    }

    // Hairline divider at the bottom
    Rectangle {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 1
        color: Theme.borderSubtle
    }
}
