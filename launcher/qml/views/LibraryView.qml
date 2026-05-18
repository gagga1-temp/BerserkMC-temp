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

    // App.instances is a QVariantList of dicts from QmlBridge. We mirror its
    // shape into a ListModel so the existing delegates (which use model.xxx)
    // keep working.
    ListModel { id: instancesModel }

    function relativeAge(epoch) {
        if (!epoch) return ""
        var diff = (Date.now() / 1000) - (epoch / 1000)
        if (diff < 0)             return ""
        if (diff < 60)            return qsTr("à l'instant")
        if (diff < 3600)          return qsTr("il y a %1 min").arg(Math.floor(diff / 60))
        if (diff < 86400)         return qsTr("il y a %1 h").arg(Math.floor(diff / 3600))
        if (diff < 86400 * 30)    return qsTr("il y a %1 j").arg(Math.floor(diff / 86400))
        if (diff < 86400 * 365)   return qsTr("il y a %1 mois").arg(Math.floor(diff / 86400 / 30))
        return qsTr("il y a %1 ans").arg(Math.floor(diff / 86400 / 365))
    }

    function formatPlaytime(seconds) {
        if (!seconds) return "—"
        var h = Math.floor(seconds / 3600)
        var m = Math.floor((seconds % 3600) / 60)
        if (h === 0) return m + " m"
        return h + " h " + m + " m"
    }

    function rebuildInstancesModel() {
        instancesModel.clear()
        if (typeof App === "undefined") return
        var list = App.instances
        for (var i = 0; i < list.length; ++i) {
            var src = list[i]
            instancesModel.append({
                id_:       src.id || "",
                name:      src.name || "(sans nom)",
                sub:       relativeAge(src.lastPlayed),
                iconSrc:   "qrc:/icons/multimc/256x256/minecraft.png",
                mc:        src.mcVersion || "",
                playtime:  formatPlaytime(src.totalPlayed),
                mods:      0
            })
        }
    }

    Component.onCompleted: rebuildInstancesModel()
    Connections {
        target: typeof App !== "undefined" ? App : null
        function onInstancesChanged() { page.rebuildInstancesModel() }
    }

    property int selectedIndex: 0
    function selectedInstance() {
        if (selectedIndex < 0 || selectedIndex >= instancesModel.count) return null;
        return instancesModel.get(selectedIndex);
    }
    function selectedInstanceId() {
        var inst = selectedInstance();
        return inst ? inst.id_ : "";
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
                onPlay: {
                    var id = page.selectedInstanceId()
                    if (id && typeof App !== "undefined") App.launchInstance(id, false)
                }
                onPlayOffline: {
                    var id = page.selectedInstanceId()
                    if (id && typeof App !== "undefined") App.launchInstance(id, true)
                }
            }
        }
    }
}
