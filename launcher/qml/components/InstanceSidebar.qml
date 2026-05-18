// SPDX-License-Identifier: Apache-2.0
// Right-hand instance details + actions sidebar.

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

import BerserkMC.Ui 1.0

Rectangle {
    id: side
    property var instance: ({ name: "—", sub: "—", iconSource: "qrc:/icons/multimc/256x256/minecraft.png", playtime: "—", mods: 0 })
    signal play()
    signal playOffline()
    signal openMods()
    signal openWorlds()
    signal openEdit()
    signal openFolder()

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
            spacing: 6

            Rectangle {
                width: 88
                height: 88
                radius: Theme.radiusLg
                anchors.horizontalCenter: parent.horizontalCenter
                color: Theme.bgElevated
                border.color: Theme.borderSubtle
                border.width: 1

                Image {
                    anchors.centerIn: parent
                    source: side.instance.iconSource || "qrc:/icons/multimc/256x256/minecraft.png"
                    sourceSize.width: 128
                    sourceSize.height: 128
                    width: 64
                    height: 64
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: side.instance.name
                color: Theme.textPrimary
                font.family: Theme.fontBody
                font.pointSize: 14
                font.weight: Font.Bold
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
                implicitHeight: 44
                radius: Theme.radiusMd
                color: playHover.containsMouse ? Theme.accent : Theme.accentSoft
                border.color: Theme.accentRing
                border.width: 1
                Behavior on color { ColorAnimation { duration: Theme.durFast } }
                scale: playHover.pressed ? 0.97 : 1
                Behavior on scale { NumberAnimation { duration: Theme.durFast; easing.type: Easing.OutCubic } }

                Row {
                    anchors.centerIn: parent
                    spacing: 8
                    Icon { name: "play"; color: playHover.containsMouse ? "white" : Theme.accentStrong; size: 16; anchors.verticalCenter: parent.verticalCenter }
                    Text {
                        text: qsTr("Jouer")
                        color: playHover.containsMouse ? "white" : Theme.accentStrong
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
                    onClicked: side.play()
                }
            }
            Rectangle {
                implicitWidth: 44
                implicitHeight: 44
                radius: Theme.radiusMd
                color: offHover.containsMouse ? Theme.bgInputOff : Theme.bgElevated
                border.color: Theme.borderSubtle
                border.width: 1
                Behavior on color { ColorAnimation { duration: Theme.durFast } }
                Icon {
                    anchors.centerIn: parent
                    name: "offline"
                    color: offHover.containsMouse ? Theme.textPrimary : Theme.textMuted
                    size: 16
                }
                MouseArea {
                    id: offHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: side.playOffline()
                    ToolTip.text: qsTr("Lancer hors-ligne (sans télécharger)")
                    ToolTip.visible: containsMouse
                    ToolTip.delay: 500
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
                    IconButton { width: parent.width; variant: "ghost"; iconName: "camera"; text: qsTr("Screenshots") }
                    IconButton { width: parent.width; variant: "ghost"; iconName: "note";   text: qsTr("Notes") }
                    IconButton { width: parent.width; variant: "ghost"; iconName: "copy";   text: qsTr("Dupliquer") }
                    IconButton { width: parent.width; variant: "ghost"; iconName: "upload"; text: qsTr("Exporter") }
                    IconButton { width: parent.width; variant: "ghost"; iconName: "link";   text: qsTr("Raccourci bureau") }
                    IconButton { width: parent.width; variant: "danger"; iconName: "trash"; text: qsTr("Supprimer") }
                }
            }

            Behavior on implicitHeight { NumberAnimation { duration: Theme.durMd; easing.type: Easing.OutCubic } }
        }

        Item { Layout.fillHeight: true }
    }
}
