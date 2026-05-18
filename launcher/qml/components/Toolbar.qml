// SPDX-License-Identifier: Apache-2.0
// Main library toolbar: Nouvelle instance / Dossiers / Réglages + account chip.

import QtQuick 2.15
import QtQuick.Layouts 1.15

import BerserkMC.Ui 1.0

Rectangle {
    id: bar
    property string accountName: "Karim_"
    property string accountInitial: "K"
    property string accountKind: "Offline"      // "Offline" | "Microsoft"

    signal newInstanceRequested()
    signal foldersRequested()
    signal settingsRequested()
    signal accountRequested()

    implicitHeight: 52
    color: Theme.bgSurface

    Rectangle {
        anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
        height: 1
        color: Theme.borderSubtle
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 4

        IconButton { text: qsTr("Nouvelle instance"); iconName: "plus"; onClicked: bar.newInstanceRequested() }
        IconButton { text: qsTr("Dossiers"); iconName: "folder"; onClicked: bar.foldersRequested() }
        IconButton { text: qsTr("Réglages"); iconName: "gear"; onClicked: bar.settingsRequested() }

        Item { Layout.fillWidth: true }

        // Account chip
        Rectangle {
            id: chip
            implicitHeight: 32
            implicitWidth: chipRow.implicitWidth + 20
            radius: 999
            color: chipHover.containsMouse ? Theme.bgInputOff : Theme.bgElevated
            border.color: chipHover.containsMouse ? Theme.border : Theme.borderSubtle
            border.width: 1
            Behavior on color { ColorAnimation { duration: Theme.durFast } }
            Behavior on border.color { ColorAnimation { duration: Theme.durFast } }

            RowLayout {
                id: chipRow
                anchors.centerIn: parent
                spacing: 8

                Rectangle {
                    implicitWidth: 24
                    implicitHeight: 24
                    radius: 12
                    color: bar.accountKind === "Offline" ? Theme.accentSoft : Qt.rgba(0.13, 0.45, 0.93, 0.18)
                    Text {
                        anchors.centerIn: parent
                        text: bar.accountInitial
                        color: bar.accountKind === "Offline" ? Theme.accentStrong : "#7ab1ff"
                        font.family: Theme.fontBody
                        font.pointSize: 9
                        font.weight: Font.Bold
                    }
                }
                Text {
                    text: bar.accountName
                    color: Theme.textPrimary
                    font.family: Theme.fontBody
                    font.pointSize: 10
                }
                Rectangle {
                    radius: 4
                    implicitWidth: kindLbl.implicitWidth + 12
                    implicitHeight: 18
                    color: bar.accountKind === "Offline" ? Theme.accentSoft : Qt.rgba(0.13, 0.45, 0.93, 0.18)
                    Text {
                        id: kindLbl
                        anchors.centerIn: parent
                        text: bar.accountKind.toUpperCase()
                        color: bar.accountKind === "Offline" ? Theme.accentStrong : "#7ab1ff"
                        font.family: Theme.fontBody
                        font.pointSize: 8
                        font.letterSpacing: 0.5
                        font.weight: Font.Bold
                    }
                }
            }

            MouseArea {
                id: chipHover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: bar.accountRequested()
            }
        }
    }
}
