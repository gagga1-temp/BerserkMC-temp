// SPDX-License-Identifier: Apache-2.0
// Main library toolbar: Nouvelle instance / Skins / Dossiers / Réglages +
// profile selector (ProfileMenu).

import QtQuick 2.15
import QtQuick.Layouts 1.15

import BerserkMC.Ui 1.0

Rectangle {
    id: bar
    property var    profiles: []
    property string activeId: ""

    signal newInstanceRequested()
    signal skinsRequested()
    signal foldersRequested()
    signal settingsRequested()
    signal accountRequested()
    signal profileActivated(string internalId)
    signal profileCreated(string playerName)

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
        IconButton { text: qsTr("Skins"); iconName: "cube"; onClicked: bar.skinsRequested() }
        IconButton { text: qsTr("Dossiers"); iconName: "folder"; onClicked: bar.foldersRequested() }
        IconButton { text: qsTr("Réglages"); iconName: "gear"; onClicked: bar.settingsRequested() }

        Item { Layout.fillWidth: true }

        // Profile selector (trigger + dropdown)
        ProfileMenu {
            Layout.alignment: Qt.AlignVCenter
            profiles: bar.profiles
            activeId: bar.activeId
            onProfileActivated: function(internalId) { bar.profileActivated(internalId) }
            onProfileCreated: function(playerName) { bar.profileCreated(playerName) }
            onAccountManagementRequested: bar.accountRequested()
        }
    }
}
