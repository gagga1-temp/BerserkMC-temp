// SPDX-License-Identifier: Apache-2.0
// Accounts view: left list of accounts, right detail panel. Offline accounts
// are first-class — the "Add offline" CTA at the bottom of the list is the
// primary action; Microsoft login is a secondary outlined button.

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

import BerserkMC.Ui 1.0
import "../components"

Rectangle {
    id: page
    color: Theme.bgBase

    signal back()

    // ===== Mock data — Phase 7 swaps in the C++ AccountList model =====
    ListModel {
        id: accounts
        ListElement { name: "Karim_";       initial: "K"; kind: "Offline";    isDefault: true  }
        ListElement { name: "SteveBuilder"; initial: "S"; kind: "Offline";    isDefault: false }
        ListElement { name: "Notch4Ever";   initial: "N"; kind: "Microsoft";  isDefault: false }
    }
    property int selectedIndex: 0
    function current() { return accounts.get(selectedIndex) }

    function makeDefault(i) {
        for (var k = 0; k < accounts.count; ++k)
            accounts.setProperty(k, "isDefault", k === i)
    }
    function remove(i) {
        if (accounts.count === 0) return
        accounts.remove(i)
        if (selectedIndex >= accounts.count) selectedIndex = accounts.count - 1
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ===== Local header with back button + section title =====
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 48
            color: "transparent"

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 20
                anchors.rightMargin: 20
                spacing: 12

                IconButton {
                    variant: "ghost"
                    dense: true
                    iconName: "arrow-left"
                    text: qsTr("Retour")
                    onClicked: page.back()
                }

                Item { Layout.fillWidth: true }
            }

            // Divider line
            Rectangle {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: 1
                color: Theme.borderSubtle
            }
        }

        // ===== Body split =====
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            // ----- Left list -----
            Rectangle {
                Layout.preferredWidth: 300
                Layout.fillHeight: true
                color: Theme.bgSurface

                Rectangle {
                    anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
                    width: 1
                    color: Theme.borderSubtle
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 6

                    Text {
                        Layout.fillWidth: true
                        text: qsTr("TES COMPTES · %1").arg(accounts.count)
                        color: Theme.textDim
                        font.family: Theme.fontBody
                        font.pointSize: 9
                        font.letterSpacing: 1
                        font.weight: Font.DemiBold
                        Layout.bottomMargin: 4
                    }

                    ScrollView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true

                        ColumnLayout {
                            width: parent.parent.availableWidth
                            spacing: 4

                            Repeater {
                                model: accounts
                                delegate: Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: 58
                                    radius: Theme.radiusMd
                                    color: index === page.selectedIndex
                                        ? Theme.accentSoft
                                        : (rowHover.containsMouse ? Theme.bgElevated : "transparent")
                                    border.color: index === page.selectedIndex ? Theme.accentRing : "transparent"
                                    border.width: 1
                                    Behavior on color { ColorAnimation { duration: Theme.durFast } }

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: 10
                                        spacing: 10

                                        // Avatar
                                        Rectangle {
                                            implicitWidth: 36; implicitHeight: 36
                                            radius: 8
                                            color: index === page.selectedIndex && model.kind === "Offline"
                                                ? Theme.accent
                                                : (model.kind === "Offline" ? Theme.bgElevated : Qt.rgba(0.13, 0.45, 0.93, 0.20))
                                            Text {
                                                anchors.centerIn: parent
                                                text: model.initial
                                                color: index === page.selectedIndex && model.kind === "Offline"
                                                    ? "white"
                                                    : (model.kind === "Offline" ? Theme.textPrimary : "#7ab1ff")
                                                font.family: Theme.fontBody
                                                font.pointSize: 12
                                                font.weight: Font.Bold
                                            }
                                        }

                                        Column {
                                            Layout.fillWidth: true
                                            spacing: 2
                                            Text {
                                                width: parent.width
                                                text: model.name
                                                color: Theme.textPrimary
                                                font.family: Theme.fontBody
                                                font.pointSize: 11
                                                font.weight: Font.DemiBold
                                                elide: Text.ElideRight
                                            }
                                            Row {
                                                spacing: 4
                                                Rectangle {
                                                    radius: 4
                                                    implicitHeight: 16
                                                    implicitWidth: kbadge.implicitWidth + 10
                                                    color: model.kind === "Offline"
                                                        ? Theme.accentSoft
                                                        : Qt.rgba(0.13, 0.45, 0.93, 0.18)
                                                    Text {
                                                        id: kbadge
                                                        anchors.centerIn: parent
                                                        text: model.kind.toUpperCase()
                                                        color: model.kind === "Offline" ? Theme.accentStrong : "#7ab1ff"
                                                        font.family: Theme.fontBody
                                                        font.pointSize: 8
                                                        font.weight: Font.Bold
                                                    }
                                                }
                                                Rectangle {
                                                    radius: 4
                                                    visible: model.isDefault
                                                    implicitHeight: 16
                                                    implicitWidth: defLbl.implicitWidth + 10
                                                    color: Theme.bgInput
                                                    Text {
                                                        id: defLbl
                                                        anchors.centerIn: parent
                                                        text: qsTr("DÉFAUT")
                                                        color: Theme.textMuted
                                                        font.family: Theme.fontBody
                                                        font.pointSize: 8
                                                        font.weight: Font.Bold
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    MouseArea {
                                        id: rowHover
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: page.selectedIndex = index
                                    }
                                }
                            }
                        }
                    }

                    // Divider
                    Rectangle { Layout.fillWidth: true; height: 1; color: Theme.borderSubtle; Layout.topMargin: 4; Layout.bottomMargin: 4 }

                    // Add buttons
                    IconButton {
                        Layout.fillWidth: true
                        variant: "primary"
                        iconName: "user"
                        text: qsTr("Ajouter compte hors-ligne")
                        onClicked: console.log("add offline (TODO open small dialog)")
                    }
                    IconButton {
                        Layout.fillWidth: true
                        variant: "filled"
                        iconName: "user"
                        text: qsTr("Ajouter compte Microsoft")
                        onClicked: console.log("add MS")
                    }
                }
            }

            // ----- Right detail -----
            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                ColumnLayout {
                    width: parent.parent.availableWidth
                    spacing: 22
                    Item { implicitHeight: 4 }

                    // Hero
                    RowLayout {
                        Layout.leftMargin: 32
                        Layout.rightMargin: 32
                        spacing: 18

                        Rectangle {
                            implicitWidth: 96; implicitHeight: 96
                            radius: Theme.radiusLg
                            color: Theme.bgElevated
                            border.color: Theme.borderSubtle
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: page.current() ? page.current().initial : ""
                                color: Theme.accentStrong
                                font.family: Theme.fontBody
                                font.pointSize: 36
                                font.weight: Font.Bold
                            }
                        }

                        Column {
                            Layout.fillWidth: true
                            spacing: 4

                            Text {
                                text: page.current() ? page.current().name : ""
                                color: Theme.textPrimary
                                font.family: Theme.fontBody
                                font.pointSize: 24
                                font.weight: Font.Bold
                            }
                            Row {
                                spacing: 8
                                Rectangle {
                                    radius: 4
                                    implicitHeight: 18
                                    implicitWidth: heroKindLbl.implicitWidth + 12
                                    color: page.current() && page.current().kind === "Offline"
                                        ? Theme.accentSoft
                                        : Qt.rgba(0.13, 0.45, 0.93, 0.18)
                                    Text {
                                        id: heroKindLbl
                                        anchors.centerIn: parent
                                        text: qsTr(page.current() ? "COMPTE %1".arg(page.current().kind.toUpperCase()) : "")
                                        color: page.current() && page.current().kind === "Offline" ? Theme.accentStrong : "#7ab1ff"
                                        font.family: Theme.fontBody
                                        font.pointSize: 9
                                        font.weight: Font.Bold
                                    }
                                }
                                Text {
                                    text: page.current() && page.current().kind === "Offline"
                                        ? qsTr("· Aucun token Mojang requis")
                                        : qsTr("· Sessions Mojang valides")
                                    color: Theme.textDim
                                    font.family: Theme.fontBody
                                    font.pointSize: 10
                                }
                            }
                        }

                        // Star — make default
                        IconButton {
                            iconName: "star"
                            variant: page.current() && page.current().isDefault ? "primary" : "filled"
                            text: page.current() && page.current().isDefault ? qsTr("Défaut") : qsTr("Par défaut")
                            onClicked: page.makeDefault(page.selectedIndex)
                        }
                    }

                    // Identifiers
                    Column {
                        Layout.leftMargin: 32
                        Layout.rightMargin: 32
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: qsTr("IDENTIFIANTS EN JEU")
                            color: Theme.textDim
                            font.family: Theme.fontBody
                            font.pointSize: 9
                            font.letterSpacing: 1
                            font.weight: Font.DemiBold
                        }

                        Row {
                            width: parent.width
                            spacing: 8
                            Rectangle {
                                width: (parent.width - 8) / 2
                                implicitHeight: 64
                                radius: Theme.radiusMd
                                color: Theme.bgSurface
                                border.color: Theme.borderSubtle
                                border.width: 1
                                Column {
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    spacing: 4
                                    Text { text: qsTr("Pseudo"); color: Theme.textDim; font.family: Theme.fontBody; font.pointSize: 9; font.letterSpacing: 0.5; font.weight: Font.DemiBold }
                                    Text { text: page.current() ? page.current().name : ""; color: Theme.textPrimary; font.family: Theme.fontMono; font.pointSize: 12 }
                                }
                            }
                            Rectangle {
                                width: (parent.width - 8) / 2
                                implicitHeight: 64
                                radius: Theme.radiusMd
                                color: Theme.bgSurface
                                border.color: Theme.borderSubtle
                                border.width: 1
                                Column {
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    spacing: 4
                                    Text { text: qsTr("UUID"); color: Theme.textDim; font.family: Theme.fontBody; font.pointSize: 9; font.letterSpacing: 0.5; font.weight: Font.DemiBold }
                                    Text {
                                        text: page.current() && page.current().kind === "Offline"
                                            ? "b9c8d1c1-2f3a-3b1c-9e2d-58e1f5c2a4b6"
                                            : "—"
                                        color: Theme.textPrimary
                                        font.family: Theme.fontMono
                                        font.pointSize: 10
                                        elide: Text.ElideRight
                                        width: parent.width
                                    }
                                }
                            }
                        }
                    }

                    // À savoir
                    Column {
                        Layout.leftMargin: 32
                        Layout.rightMargin: 32
                        Layout.fillWidth: true
                        spacing: 8
                        visible: page.current() && page.current().kind === "Offline"

                        Text {
                            text: qsTr("À SAVOIR")
                            color: Theme.textDim
                            font.family: Theme.fontBody
                            font.pointSize: 9
                            font.letterSpacing: 1
                            font.weight: Font.DemiBold
                        }
                        Rectangle {
                            width: parent.width
                            implicitHeight: noteText.implicitHeight + 28
                            radius: Theme.radiusMd
                            color: Theme.bgSurface
                            border.color: Theme.borderSubtle
                            border.width: 1
                            Text {
                                id: noteText
                                anchors.fill: parent
                                anchors.margins: 14
                                text: qsTr("Ce compte ne fonctionne pas sur les serveurs publics (online-mode=true) comme Hypixel. Il marche en solo, en LAN, et sur les serveurs avec l'authentification désactivée.")
                                color: Theme.textMuted
                                font.family: Theme.fontBody
                                font.pointSize: 10
                                wrapMode: Text.WordWrap
                                textFormat: Text.PlainText
                            }
                        }
                    }

                    // Actions
                    Column {
                        Layout.leftMargin: 32
                        Layout.rightMargin: 32
                        Layout.bottomMargin: 24
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: qsTr("ACTIONS")
                            color: Theme.textDim
                            font.family: Theme.fontBody
                            font.pointSize: 9
                            font.letterSpacing: 1
                            font.weight: Font.DemiBold
                        }

                        Row {
                            spacing: 8
                            IconButton {
                                variant: "filled"
                                iconName: "pencil"
                                text: qsTr("Renommer")
                            }
                            IconButton {
                                variant: "danger"
                                iconName: "trash"
                                text: qsTr("Supprimer")
                                onClicked: page.remove(page.selectedIndex)
                            }
                        }
                    }
                }
            }
        }
    }
}
