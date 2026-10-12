// SPDX-License-Identifier: Apache-2.0
// Library view: toolbar + instance grid + sidebar. The instance list is the
// real one, mirrored from App.instances (QmlBridge) into a ListModel below.

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

import BerserkMC.Ui 1.0
import "../components"

Rectangle {
    id: page
    color: Theme.bgBase

    readonly property string viewTitle: "BIBLIOTHÈQUE"
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

    // Route every instance icon through the cpp QmlIconProvider so we honour
    // user-custom icons too. The provider falls back to the default Minecraft
    // grass-block when the key is unknown.
    function iconPathFor(key) {
        var safe = (key && key.length) ? key : "default"
        return "image://mmcicon/" + safe
    }

    function rebuildInstancesModel() {
        page.rawInstances = []
        if (typeof App === "undefined") return
        page.rawInstances = App.instances
        page.applyInstancesFilter()
    }

    // Raw (unfiltered) source so the search box can swap the visible list
    // without re-reading the bridge model.
    property var rawInstances: []

    function applyInstancesFilter() {
        instancesModel.clear()
        var q = search.text.trim().toLowerCase()
        for (var i = 0; i < rawInstances.length; ++i) {
            var src = rawInstances[i]
            if (q.length && src.name.toLowerCase().indexOf(q) < 0) continue
            instancesModel.append({
                id_:       src.id || "",
                name:      src.name || "(sans nom)",
                sub:       relativeAge(src.lastPlayed),
                iconSrc:   iconPathFor(src.iconKey),
                mc:        src.mcVersion || "",
                playtime:  formatPlaytime(src.totalPlayed),
                mods:      src.mods || 0
            })
        }
    }

    function filtered() {
        return search.text.trim().length > 0
    }

    function instanceCountLabel() {
        return qsTr("BIBLIOTHÈQUE · %1 INSTANCES").arg(instancesModel.count)
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
                            text: page.instanceCountLabel()
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
                                onTextChanged: page.applyInstancesFilter()
                            }
                        }
                    }

                    // Empty state — shown only when no instances at all (the
                    // "Add" tile inside the Flow handles the +1 case too, but
                    // this gives a real welcome to fresh installs).
                    Column {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.alignment: Qt.AlignCenter
                        spacing: 14
                        visible: instancesModel.count === 0
                        Icon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            name: "pickaxe"
                            color: Theme.textDim
                            size: 64
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: page.filtered()
                                ? qsTr("Aucun résultat pour « %1 »").arg(search.text)
                                : qsTr("Aucune instance pour l'instant")
                            color: Theme.textPrimary
                            font.family: Theme.fontBody
                            font.pointSize: 14
                            font.weight: Font.DemiBold
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            visible: !page.filtered()
                            text: qsTr("Crée ta première instance pour commencer à jouer.")
                            color: Theme.textDim
                            font.family: Theme.fontBody
                            font.pointSize: 11
                        }
                        IconButton {
                            anchors.horizontalCenter: parent.horizontalCenter
                            visible: !page.filtered()
                            variant: "primary"
                            iconName: "plus"
                            text: qsTr("Créer une instance")
                            onClicked: page.newInstanceRequested()
                        }
                    }

                    // Card grid — Flow lays cards out left-to-right, wraps on
                    // overflow. ScrollView.availableWidth binding makes Flow
                    // honour the real visible width inside the scroll viewport.
                    ScrollView {
                        visible: instancesModel.count > 0
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
                                        running: typeof App !== "undefined" && App.runningInstances.indexOf(model.id_) >= 0
                                        onClicked: page.selectedIndex = index
                                        onDoubleClicked: {
                                            if (typeof App !== "undefined") App.launchInstance(model.id_, true)
                                        }
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
                instanceId: page.selectedInstanceId()
                isRunning: typeof App !== "undefined" && App.runningInstances.indexOf(instanceId) >= 0
                onKill: {
                    if (instanceId && typeof App !== "undefined") App.killInstance(instanceId)
                }
                instance: {
                    var inst = page.selectedInstance();
                    if (!inst) return { name: qsTr("Aucune sélection"), sub: "—",
                                        iconSource: "qrc:/icons/berserkmc/256x256/minecraft.png",
                                        playtime: "—", mods: 0 };
                    return { name: inst.name, sub: inst.mc,
                             iconSource: inst.iconSrc,
                             playtime: inst.playtime, mods: inst.mods };
                }
                onPlay: {
                    var id = page.selectedInstanceId()
                    if (id && typeof App !== "undefined") App.launchInstance(id, true)
                }
                onOpenMods: {
                    var id = page.selectedInstanceId()
                    if (id && typeof App !== "undefined") App.viewMods(id)
                }
                onOpenWorlds: {
                    var id = page.selectedInstanceId()
                    if (id && typeof App !== "undefined") App.viewWorlds(id)
                }
                onOpenEdit: {
                    var id = page.selectedInstanceId()
                    if (id && typeof App !== "undefined") App.editInstance(id, "")
                }
                onOpenFolder: {
                    var id = page.selectedInstanceId()
                    if (id && typeof App !== "undefined") App.openFolder("minecraft:" + id)
                }
                onOpenScreenshots: {
                    var id = page.selectedInstanceId()
                    if (id && typeof App !== "undefined") App.manageScreenshots(id)
                }
                onOpenNotes: {
                    var id = page.selectedInstanceId()
                    if (id && typeof App !== "undefined") App.editNotes(id)
                }
                onDuplicateRequested: {
                    var id = page.selectedInstanceId()
                    if (id && typeof App !== "undefined") App.duplicateInstance(id)
                }
                onExportRequested: {
                    var id = page.selectedInstanceId()
                    if (id && typeof App !== "undefined") App.exportInstance(id)
                }
                onShortcutRequested: {
                    var id = page.selectedInstanceId()
                    if (id && typeof App !== "undefined") App.createShortcut(id)
                }
                onDeleteRequested: {
                    var id = page.selectedInstanceId()
                    if (id && typeof App !== "undefined") App.deleteInstance(id)
                }
            }
        }
    }
}
