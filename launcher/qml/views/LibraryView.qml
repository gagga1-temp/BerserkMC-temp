// SPDX-License-Identifier: Apache-2.0
// Library view: toolbar + instance grid + sidebar. Phase 3 uses mock data —
// Phase 7 swaps it for the real InstanceList model from the C++ side.

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

import BerserkMC.Ui 1.0
import "../components"

Rectangle {
    id: page
    color: Theme.bgBase

    property string playerName: "Player"
    property string accountKind: "Offline"

    signal accountsRequested()
    signal settingsRequested()
    signal newInstanceRequested()
    signal foldersRequested()

    // ===== Mock instance data =====
    ListModel {
        id: instancesModel
        ListElement { name: "1.14.4 Vanilla"; sub: "il y a 2h"; iconSrc: "qrc:/icons/multimc/256x256/minecraft.png";          mc: "Minecraft 1.14.4 · Vanilla"; playtime: "14h 23m"; mods: 0 }
        ListElement { name: "1.20.1 Fabric";  sub: "hier";      iconSrc: "qrc:/icons/multimc/128x128/instances/enderpearl.png"; mc: "Minecraft 1.20.1 · Fabric";  playtime: "3h 12m";  mods: 28 }
        ListElement { name: "Modpack Tech";   sub: "il y a 5j"; iconSrc: "qrc:/icons/multimc/128x128/instances/flame.png";    mc: "Minecraft 1.19.2 · Forge";   playtime: "27h 41m"; mods: 142 }
    }

    property int selectedIndex: 0
    function selectedInstance() {
        if (selectedIndex < 0 || selectedIndex >= instancesModel.count) return null;
        return instancesModel.get(selectedIndex);
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Toolbar {
            id: tb
            Layout.fillWidth: true
            accountName:    page.playerName
            accountInitial: page.playerName.length ? page.playerName.charAt(0).toUpperCase() : "?"
            accountKind:    page.accountKind
            onAccountRequested:     page.accountsRequested()
            onSettingsRequested:    page.settingsRequested()
            onNewInstanceRequested: page.newInstanceRequested()
            onFoldersRequested:     page.foldersRequested()
        }

        // ===== Body =====
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            // ----- Instance grid -----
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                ColumnLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 28
                    anchors.rightMargin: 28
                    anchors.topMargin: 24
                    anchors.bottomMargin: 24
                    spacing: 20

                    // Header row
                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: qsTr("BIBLIOTHÈQUE · %1 INSTANCES").arg(instancesModel.count)
                            color: Theme.textDim
                            font.family: Theme.fontBody
                            font.pointSize: 9
                            font.letterSpacing: 1
                            font.weight: Font.DemiBold
                        }
                        Item { Layout.fillWidth: true }

                        // Search field
                        Rectangle {
                            implicitWidth: 240
                            implicitHeight: 32
                            radius: Theme.radiusMd
                            color: Theme.bgSurface
                            border.color: search.activeFocus ? Theme.accentRing : Theme.borderSubtle
                            border.width: 1
                            Behavior on border.color { ColorAnimation { duration: Theme.durFast } }

                            Icon {
                                anchors.left: parent.left
                                anchors.leftMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                name: "search"
                                color: Theme.textDim
                                size: 14
                            }
                            TextField {
                                id: search
                                anchors.fill: parent
                                anchors.leftMargin: 30
                                anchors.rightMargin: 8
                                placeholderText: qsTr("Rechercher…")
                                color: Theme.textPrimary
                                placeholderTextColor: Theme.textDim
                                font.family: Theme.fontBody
                                font.pointSize: 10
                                background: null
                                verticalAlignment: TextInput.AlignVCenter
                            }
                        }
                    }

                    // Card grid — Flow lays cards out left-to-right, wraps on
                    // overflow. ScrollView.availableWidth binding makes Flow
                    // honour the real visible width inside the scroll viewport.
                    ScrollView {
                        id: gridScroll
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                        contentWidth: availableWidth

                        // Padding wrapper: gives the hover-scale (and selected
                        // halo) breathing room so the top edge of a scaled card
                        // doesn't get clipped by the ScrollView viewport.
                        Item {
                            id: gridPad
                            width: gridScroll.availableWidth
                            implicitHeight: cardFlow.implicitHeight + 12

                            Flow {
                                id: cardFlow
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.leftMargin: 6
                                anchors.rightMargin: 6
                                anchors.topMargin: 13
                                spacing: 14

                                Repeater {
                                    model: instancesModel
                                    delegate: InstanceCard {
                                        name: model.name
                                        sub: model.sub
                                        iconSource: model.iconSrc
                                        selected: index === page.selectedIndex
                                        onClicked: page.selectedIndex = index
                                        onDoubleClicked: console.log("launch", model.name)
                                    }
                                }

                                // Add tile
                                InstanceCard {
                                    addTile: true
                                    name: qsTr("Ajouter")
                                    onClicked: tb.newInstanceRequested()
                                }
                            }
                        }
                    }
                }
            }

            // ----- Sidebar -----
            InstanceSidebar {
                Layout.preferredWidth: 320
                Layout.fillHeight: true
                instance: {
                    var inst = page.selectedInstance();
                    if (!inst) return { name: qsTr("Aucune sélection"), sub: "—",
                                        iconSource: "qrc:/icons/multimc/256x256/minecraft.png",
                                        playtime: "—", mods: 0 };
                    return { name: inst.name, sub: inst.mc,
                             iconSource: inst.iconSrc,
                             playtime: inst.playtime, mods: inst.mods };
                }
                onPlay: console.log("play", instance.name)
                onPlayOffline: console.log("play offline", instance.name)
            }
        }
    }
}
