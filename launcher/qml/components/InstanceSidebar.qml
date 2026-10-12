// SPDX-License-Identifier: Apache-2.0
// Right-hand instance details + actions sidebar.

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

import BerserkMC.Ui 1.0

Rectangle {
    id: side
    property var instance: ({ name: "—", sub: "—", iconSource: "qrc:/icons/berserkmc/256x256/minecraft.png", playtime: "—", mods: 0 })
    property string instanceId: ""
    property bool   isRunning: false
    signal play()
    signal kill()
    signal openMods()
    signal openWorlds()
    signal openEdit()
    signal openFolder()
    signal openScreenshots()
    signal openNotes()
    signal duplicateRequested()
    signal exportRequested()
    signal shortcutRequested()
    signal deleteRequested()

    color: Theme.bgSurface

    Rectangle {
        anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
        width: 1
        color: Theme.borderSubtle
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 16

        // ===== Hero =====
        Column {
            Layout.alignment: Qt.AlignHCenter
            spacing: 10

            // Icon tile with a subtle accent backdrop for visual weight.
            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                implicitWidth: 112
                implicitHeight: 112

                // Soft halo behind the icon
                Rectangle {
                    anchors.centerIn: parent
                    width: 132; height: 132
                    radius: 66
                    color: Theme.accentGlow2
                    opacity: 0.9
                }
                Rectangle {
                    anchors.fill: parent
                    radius: Theme.radiusLg
                    color: Theme.bgElevated
                    border.color: Theme.borderSubtle
                    border.width: 1
                }
                Image {
                    anchors.centerIn: parent
                    source: side.instance.iconSource || "qrc:/icons/berserkmc/256x256/minecraft.png"
                    sourceSize.width: 200; sourceSize.height: 200
                    width: 84; height: 84
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: side.instance.name
                color: Theme.textPrimary
                font.family: Theme.fontBody
                font.pointSize: 15
                font.weight: Font.Bold
                font.letterSpacing: -0.2
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: side.instance.sub
                color: Theme.textDim
                font.family: Theme.fontBody
                font.pointSize: 9
            }
        }

        // ===== Play row =====
        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Rectangle {
                id: playBtn
                Layout.fillWidth: true
                implicitHeight: 52
                radius: Theme.radiusMd
                color: side.isRunning
                    ? (playHover.containsMouse ? Theme.accentRed : Qt.rgba(1, 0.36, 0.36, 0.18))
                    : (playHover.containsMouse ? Theme.accent : Theme.accentSoft)
                border.color: side.isRunning ? Qt.rgba(1, 0.36, 0.36, 0.4) : Theme.accentRing
                border.width: 1
                Behavior on color        { ColorAnimation { duration: Theme.durFast } }
                Behavior on border.color { ColorAnimation { duration: Theme.durFast } }
                scale: playHover.pressed ? 0.97 : 1
                Behavior on scale { NumberAnimation { duration: Theme.durFast; easing.type: Easing.OutCubic } }
                // Glow on hover
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: -2
                    radius: parent.radius + 2
                    color: "transparent"
                    border.color: playHover.containsMouse
                        ? (side.isRunning ? Qt.rgba(1, 0.36, 0.36, 0.25) : Theme.accentGlow1)
                        : "transparent"
                    border.width: 4
                    z: -1
                    Behavior on border.color { ColorAnimation { duration: Theme.durFast } }
                }

                Row {
                    anchors.centerIn: parent
                    spacing: 8
                    Icon {
                        name: side.isRunning ? "trash" : "play"
                        color: {
                            if (side.isRunning) return playHover.containsMouse ? "white" : "#ff8888"
                            return playHover.containsMouse ? "white" : Theme.accentStrong
                        }
                        size: 16
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: side.isRunning ? qsTr("Arrêter") : qsTr("Jouer")
                        color: {
                            if (side.isRunning) return playHover.containsMouse ? "white" : "#ff8888"
                            return playHover.containsMouse ? "white" : Theme.accentStrong
                        }
                        font.family: Theme.fontBody
                        font.pointSize: 11
                        font.weight: Font.Bold
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
                MouseArea {
                    id: playHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: side.isRunning ? side.kill() : side.play()
                }
            }
        }

        // ===== Stats =====
        Row {
            Layout.fillWidth: true
            spacing: 6
            Rectangle {
                width: (parent.width - 6) / 2; height: 56
                radius: Theme.radiusMd
                color: Theme.bgElevated
                border.color: Theme.borderSubtle
                border.width: 1
                Column {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 2
                    Text {
                        text: qsTr("JOUÉ")
                        color: Theme.textDim
                        font.family: Theme.fontBody
                        font.pointSize: 8
                        font.letterSpacing: 0.5
                    }
                    Text {
                        text: side.instance.playtime
                        color: Theme.textPrimary
                        font.family: Theme.fontBody
                        font.pointSize: 12
                        font.weight: Font.DemiBold
                    }
                }
            }
            Rectangle {
                width: (parent.width - 6) / 2; height: 56
                radius: Theme.radiusMd
                color: Theme.bgElevated
                border.color: Theme.borderSubtle
                border.width: 1
                Column {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 2
                    Text {
                        text: qsTr("MODS")
                        color: Theme.textDim
                        font.family: Theme.fontBody
                        font.pointSize: 8
                        font.letterSpacing: 0.5
                    }
                    Text {
                        text: side.instance.mods
                        color: Theme.textPrimary
                        font.family: Theme.fontBody
                        font.pointSize: 12
                        font.weight: Font.DemiBold
                    }
                }
            }
        }

        // ===== Actions grid =====
        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: 6
            rowSpacing: 6

            IconButton { Layout.fillWidth: true; variant: "filled"; iconName: "mods";    text: qsTr("Mods");    onClicked: side.openMods() }
            IconButton { Layout.fillWidth: true; variant: "filled"; iconName: "worlds";  text: qsTr("Mondes");  onClicked: side.openWorlds() }
            IconButton { Layout.fillWidth: true; variant: "filled"; iconName: "pencil";  text: qsTr("Éditer"); onClicked: side.openEdit() }
            IconButton { Layout.fillWidth: true; variant: "filled"; iconName: "folder";  text: qsTr("Dossier"); onClicked: side.openFolder() }
        }

        // ===== Expandable "Plus d'actions" =====
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: morePane.contentY + (moreOpen ? more.implicitHeight : 0) + 40
            radius: Theme.radiusMd
            color: Theme.bgElevated
            border.color: Theme.borderSubtle
            border.width: 1
            clip: true

            property bool moreOpen: false
            id: morePane

            property real contentY: 0

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 0
                spacing: 0

                IconButton {
                    Layout.fillWidth: true
                    variant: "ghost"
                    iconName: "dots-h"
                    text: morePane.moreOpen ? qsTr("Replier") : qsTr("Plus d'actions")
                    onClicked: morePane.moreOpen = !morePane.moreOpen
                }

                Column {
                    id: more
                    Layout.fillWidth: true
                    visible: morePane.moreOpen
                    spacing: 0
                    IconButton { width: parent.width; variant: "ghost";  iconName: "camera"; text: qsTr("Screenshots");      onClicked: side.openScreenshots() }
                    IconButton { width: parent.width; variant: "ghost";  iconName: "note";   text: qsTr("Notes");           onClicked: side.openNotes() }
                    IconButton { width: parent.width; variant: "ghost";  iconName: "copy";   text: qsTr("Dupliquer");       onClicked: side.duplicateRequested() }
                    IconButton { width: parent.width; variant: "ghost";  iconName: "upload"; text: qsTr("Exporter");        onClicked: side.exportRequested() }
                    IconButton { width: parent.width; variant: "ghost";  iconName: "link";   text: qsTr("Raccourci bureau"); onClicked: side.shortcutRequested() }
                    IconButton { width: parent.width; variant: "danger"; iconName: "trash";  text: qsTr("Supprimer");       onClicked: side.deleteRequested() }
                }
            }

            Behavior on implicitHeight { NumberAnimation { duration: Theme.durMd; easing.type: Easing.OutCubic } }
        }

        Item { Layout.fillHeight: true }
    }
}
