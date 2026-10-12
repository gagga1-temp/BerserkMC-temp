// SPDX-License-Identifier: Apache-2.0
// New-instance wizard. Left tabs choose source (Vanilla / Modrinth / CurseForge
// / Import zip); right pane shows the form for the active tab. Phase 6 only
// implements the Vanilla form — the other tabs are stubs until we wire up the
// real mod-platform pages from cpp.

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

import BerserkMC.Ui 1.0
import "../components"

Rectangle {
    id: page
    color: Theme.bgBase

    readonly property string viewTitle: "NOUVELLE INSTANCE"
    signal back()
    signal created(string instanceName, string version, string loader)

    property int tabIndex: 0  // 0=Vanilla, 1=Modrinth, 2=CurseForge, 3=Import
    property string selectedLoader: "Aucun"
    property string selectedVersion: ""
    property string instanceName: ""

    // The Create button is only valid once a name and a version are known —
    // this blocks the old "fires with the default version before load" path.
    readonly property bool canCreate: tabIndex === 0
        && instanceName.trim().length > 0
        && selectedVersion.length > 0
        && !loadingVersions

    ListModel {
        id: tabs
        ListElement { label: "Vanilla";      icon: "cube";   available: true }
        ListElement { label: "Modrinth";     icon: "pack";   available: false }
        ListElement { label: "CurseForge";   icon: "pack";   available: false }
        ListElement { label: "Importer .zip"; icon: "upload"; available: false }
    }

    // Full live version list fetched from Mojang's launchermeta on mount.
    // No cpp wiring needed — QML's XMLHttpRequest does the GET, JSON.parse
    // does the rest. Phase 7 swaps this out for the cpp MinecraftVersionList
    // model when we want offline caching and bundled metadata.
    property string latestRelease: ""
    property string latestSnapshot: ""
    property string filter: "release"          // release | snapshot | all
    property bool loadingVersions: true
    property string loadError: ""

    ListModel { id: allVersions }
    ListModel { id: versions }     // filtered view bound to the list UI

    function rebuildVersions() {
        versions.clear()
        var seen = 0
        for (var i = 0; i < allVersions.count; ++i) {
            var v = allVersions.get(i)
            var keep = false
            if (page.filter === "all") keep = true
            else if (page.filter === "release") keep = (v.type === "release")
            else if (page.filter === "snapshot") keep = (v.type === "snapshot")
            else if (page.filter === "old") keep = (v.type === "old_beta" || v.type === "old_alpha")
            if (keep) {
                versions.append({
                    id_: v.id_,
                    age: v.age,
                    badge: v.id_ === page.latestRelease ? "LATEST"
                         : v.id_ === page.latestSnapshot ? "SNAPSHOT"
                         : v.type.replace("_", " ").toUpperCase(),
                    type: v.type
                })
                seen++
                if (seen >= 400) break    // cap render cost; old Minecraft has 1000+ snaps
            }
        }
        // Initial selection: latest of the active filter
        if (versions.count > 0)
            page.selectedVersion = versions.get(0).id_
    }
    onFilterChanged: rebuildVersions()

    function humanizeAge(iso) {
        if (!iso) return ""
        var then = new Date(iso).getTime()
        if (isNaN(then)) return ""
        var diff = (Date.now() - then) / 1000
        if (diff < 60)            return "à l'instant"
        if (diff < 3600)          return Math.floor(diff / 60) + " min"
        if (diff < 86400)         return Math.floor(diff / 3600) + " h"
        if (diff < 86400 * 30)    return "il y a " + Math.floor(diff / 86400) + " j"
        if (diff < 86400 * 365)   return "il y a " + Math.floor(diff / 86400 / 30) + " mois"
        return "il y a " + Math.floor(diff / 86400 / 365) + " ans"
    }

    function fetchVersions() {
        page.loadingVersions = true
        page.loadError = ""
        var xhr = new XMLHttpRequest()
        xhr.open("GET", "https://launchermeta.mojang.com/mc/game/version_manifest_v2.json")
        xhr.setRequestHeader("Accept", "application/json")
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            if (xhr.status !== 200) {
                page.loadError = qsTr("Manifest indisponible (HTTP %1)").arg(xhr.status)
                page.loadingVersions = false
                return
            }
            try {
                var data = JSON.parse(xhr.responseText)
                page.latestRelease  = data.latest.release  || ""
                page.latestSnapshot = data.latest.snapshot || ""
                allVersions.clear()
                for (var i = 0; i < data.versions.length; ++i) {
                    var v = data.versions[i]
                    allVersions.append({
                        id_: v.id,
                        type: v.type,                              // release | snapshot | old_beta | old_alpha
                        age:  humanizeAge(v.releaseTime),
                        releaseTime: v.releaseTime
                    })
                }
                rebuildVersions()
                page.loadingVersions = false
            } catch (e) {
                page.loadError = qsTr("Manifest illisible : %1").arg(e.toString())
                page.loadingVersions = false
            }
        }
        xhr.send()
    }

    Component.onCompleted: fetchVersions()

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        PageHeader {
            Layout.fillWidth: true
            iconName: "plus"
            title: qsTr("Nouvelle instance")
            subtitle: page.loadingVersions
                ? qsTr("Chargement du manifest…")
                : qsTr("%1 versions disponibles").arg(versions.count)
            onBack: page.back()
        }

        // ===== Body =====
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            // Left tab strip
            Rectangle {
                Layout.preferredWidth: 220
                Layout.fillHeight: true
                color: Theme.bgSurface

                Rectangle {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 1
                    color: Theme.borderSubtle
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 4

                    Repeater {
                        model: tabs
                        delegate: Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 44
                            radius: Theme.radiusMd
                            opacity: model.available ? 1 : 0.4
                            color: index === page.tabIndex
                                ? Theme.accentSoft
                                : (tabHover.containsMouse && model.available ? Theme.bgElevated : "transparent")
                            border.color: index === page.tabIndex ? Theme.accentRing : "transparent"
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: Theme.durFast } }

                            // Accent stripe on the left edge when active.
                            Rectangle {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.leftMargin: 4
                                width: 3
                                height: parent.height - 16
                                radius: 1.5
                                color: Theme.accentStrong
                                visible: index === page.tabIndex
                            }

                            Row {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.leftMargin: 14
                                spacing: 12

                                Icon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    name: model.icon
                                    color: index === page.tabIndex ? Theme.accentStrong : Theme.textMuted
                                    size: 16
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: model.label
                                    color: index === page.tabIndex ? Theme.accentStrong : Theme.textPrimary
                                    font.family: Theme.fontBody
                                    font.pointSize: 11
                                    font.weight: Font.DemiBold
                                }
                            }

                            MouseArea {
                                id: tabHover
                                anchors.fill: parent
                                hoverEnabled: true
                                enabled: model.available
                                cursorShape: model.available ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                                onClicked: page.tabIndex = index
                                ToolTip.visible: tabHover.containsMouse && !model.available
                                ToolTip.text: qsTr("Bientôt disponible dans BerserkMC")
                                ToolTip.delay: 250
                            }
                        }
                    }
                    Item { Layout.fillHeight: true }
                }
            }

            // Right body
            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                ColumnLayout {
                    width: parent.parent.availableWidth
                    spacing: 22

                    // Heading
                    Column {
                        Layout.topMargin: 28
                        Layout.leftMargin: 36
                        Layout.rightMargin: 36
                        spacing: 4

                        Text {
                            text: tabs.get(page.tabIndex).label
                            color: Theme.textPrimary
                            font.family: Theme.fontBody
                            font.pointSize: 18
                            font.weight: Font.Bold
                        }
                        Text {
                            text: page.tabIndex === 0
                                ? qsTr("Crée une instance vanilla ou avec un mod loader (Fabric / Forge / Quilt / NeoForge).")
                                : qsTr("Cette source n'est pas encore disponible dans BerserkMC.")
                            color: Theme.textDim
                            font.family: Theme.fontBody
                            font.pointSize: 10
                        }
                    }

                    // Form (Vanilla only for now)
                    ColumnLayout {
                        visible: page.tabIndex === 0
                        Layout.leftMargin: 36
                        Layout.rightMargin: 36
                        Layout.fillWidth: true
                        spacing: 22

                        // Name
                        Column {
                            Layout.fillWidth: true
                            spacing: 6
                            Text {
                                text: qsTr("NOM DE L'INSTANCE")
                                color: Theme.textDim
                                font.family: Theme.fontBody
                                font.pointSize: 9
                                font.letterSpacing: 1
                                font.weight: Font.DemiBold
                            }
                            Rectangle {
                                width: parent.width
                                implicitHeight: 42
                                radius: Theme.radiusMd
                                color: Theme.bgInput
                                border.color: nameInput.activeFocus ? Theme.accentRing : Theme.borderSubtle
                                border.width: 1
                                Behavior on border.color { ColorAnimation { duration: Theme.durFast } }
                                TextField {
                                    id: nameInput
                                    anchors.fill: parent
                                    anchors.leftMargin: 14
                                    anchors.rightMargin: 14
                                    text: page.instanceName
                                    placeholderText: qsTr("Ex. Ma survie")
                                    color: Theme.textPrimary
                                    font.family: Theme.fontBody
                                    font.pointSize: 11
                                    background: null
                                    verticalAlignment: TextInput.AlignVCenter
                                    onTextChanged: page.instanceName = text
                                }
                            }
                        }

                        // Loader pills
                        Column {
                            Layout.fillWidth: true
                            spacing: 6
                            Text {
                                text: qsTr("MOD LOADER")
                                color: Theme.textDim
                                font.family: Theme.fontBody
                                font.pointSize: 9
                                font.letterSpacing: 1
                                font.weight: Font.DemiBold
                            }
                            Flow {
                                width: parent.width
                                spacing: 6
                                Repeater {
                                    model: [ "Aucun", "Fabric", "Forge", "Quilt", "NeoForge" ]
                                    delegate: Rectangle {
                                        implicitHeight: 32
                                        implicitWidth: pillText.implicitWidth + 24
                                        radius: 999
                                        color: page.selectedLoader === modelData
                                            ? Theme.accentSoft
                                            : (pillHover.containsMouse ? Theme.bgElevated : Theme.bgSurface)
                                        border.color: page.selectedLoader === modelData ? Theme.accentRing : Theme.borderSubtle
                                        border.width: 1
                                        Behavior on color { ColorAnimation { duration: Theme.durFast } }
                                        Text {
                                            id: pillText
                                            anchors.centerIn: parent
                                            text: modelData
                                            color: page.selectedLoader === modelData ? Theme.accentStrong : Theme.textMuted
                                            font.family: Theme.fontBody
                                            font.pointSize: 11
                                        }
                                        MouseArea {
                                            id: pillHover
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: page.selectedLoader = modelData
                                        }
                                    }
                                }
                            }
                        }

                        // Versions
                        Column {
                            Layout.fillWidth: true
                            spacing: 8

                            // Header: label + status + filter chips
                            RowLayout {
                                width: parent.width
                                spacing: 8

                                Text {
                                    text: qsTr("VERSION MINECRAFT")
                                    color: Theme.textDim
                                    font.family: Theme.fontBody
                                    font.pointSize: 9
                                    font.letterSpacing: 1
                                    font.weight: Font.DemiBold
                                }
                                Text {
                                    visible: page.loadingVersions
                                    text: qsTr("· chargement…")
                                    color: Theme.textDim
                                    font.family: Theme.fontBody
                                    font.pointSize: 9
                                }
                                Text {
                                    visible: !page.loadingVersions && !page.loadError
                                    text: qsTr("· %1 résultats").arg(versions.count)
                                    color: Theme.textDim
                                    font.family: Theme.fontBody
                                    font.pointSize: 9
                                }

                                Item { Layout.fillWidth: true }

                                Repeater {
                                    model: [
                                        { key: "release",  label: qsTr("Releases") },
                                        { key: "snapshot", label: qsTr("Snapshots") },
                                        { key: "old",      label: qsTr("Old") },
                                        { key: "all",      label: qsTr("Tout") }
                                    ]
                                    delegate: Rectangle {
                                        implicitHeight: 24
                                        implicitWidth: chipText.implicitWidth + 18
                                        radius: 999
                                        color: page.filter === modelData.key
                                            ? Theme.accentSoft
                                            : (chipHover.containsMouse ? Theme.bgElevated : "transparent")
                                        border.color: page.filter === modelData.key
                                            ? Theme.accentRing
                                            : Theme.borderSubtle
                                        border.width: 1
                                        Behavior on color { ColorAnimation { duration: Theme.durFast } }
                                        Text {
                                            id: chipText
                                            anchors.centerIn: parent
                                            text: modelData.label
                                            color: page.filter === modelData.key
                                                ? Theme.accentStrong
                                                : Theme.textMuted
                                            font.family: Theme.fontBody
                                            font.pointSize: 9
                                            font.weight: Font.DemiBold
                                        }
                                        MouseArea {
                                            id: chipHover
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: page.filter = modelData.key
                                        }
                                    }
                                }
                            }

                            // Error banner
                            Rectangle {
                                visible: page.loadError.length > 0
                                width: parent.width
                                implicitHeight: errText.implicitHeight + 20
                                radius: Theme.radiusMd
                                color: Qt.rgba(1, 0.36, 0.36, 0.08)
                                border.color: Qt.rgba(1, 0.36, 0.36, 0.3)
                                border.width: 1
                                Row {
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    spacing: 10
                                    Text {
                                        id: errText
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: page.loadError
                                        color: "#ffa9a9"
                                        font.family: Theme.fontBody
                                        font.pointSize: 10
                                    }
                                    IconButton {
                                        anchors.verticalCenter: parent.verticalCenter
                                        variant: "filled"
                                        dense: true
                                        text: qsTr("Réessayer")
                                        onClicked: page.fetchVersions()
                                    }
                                }
                            }

                            // List
                            Rectangle {
                                width: parent.width
                                implicitHeight: 280
                                radius: Theme.radiusMd
                                color: Theme.bgSurface
                                border.color: Theme.borderSubtle
                                border.width: 1
                                clip: true

                                Column {
                                    anchors.centerIn: parent
                                    visible: page.loadingVersions
                                    spacing: 8
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: qsTr("Récupération de toutes les versions Minecraft…")
                                        color: Theme.textMuted
                                        font.family: Theme.fontBody
                                        font.pointSize: 11
                                    }
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: qsTr("(manifest officiel Mojang)")
                                        color: Theme.textDim
                                        font.family: Theme.fontBody
                                        font.pointSize: 9
                                    }
                                }

                                ListView {
                                    id: versionListView
                                    anchors.fill: parent
                                    visible: !page.loadingVersions && versions.count > 0
                                    model: versions
                                    spacing: 0
                                    clip: true
                                    boundsBehavior: Flickable.StopAtBounds
                                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                                    delegate: Rectangle {
                                        width: ListView.view.width
                                        implicitHeight: 38
                                        color: page.selectedVersion === model.id_
                                            ? Theme.accentSoft
                                            : (vHover.containsMouse ? Theme.bgElevated : "transparent")
                                        Behavior on color { ColorAnimation { duration: Theme.durFast } }

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 14
                                            anchors.rightMargin: 14
                                            spacing: 14

                                            Text {
                                                text: model.id_
                                                color: page.selectedVersion === model.id_ ? Theme.accentStrong : Theme.textPrimary
                                                font.family: Theme.fontBody
                                                font.pointSize: 11
                                                font.weight: Font.DemiBold
                                            }
                                            Item { Layout.fillWidth: true }
                                            Text {
                                                text: model.age
                                                color: Theme.textDim
                                                font.family: Theme.fontBody
                                                font.pointSize: 10
                                            }
                                            Rectangle {
                                                radius: 4
                                                implicitHeight: 16
                                                implicitWidth: badge.implicitWidth + 10
                                                color: page.selectedVersion === model.id_ ? Theme.accent : Theme.bgInput
                                                Text {
                                                    id: badge
                                                    anchors.centerIn: parent
                                                    text: model.badge
                                                    color: page.selectedVersion === model.id_ ? "white" : Theme.textMuted
                                                    font.family: Theme.fontBody
                                                    font.pointSize: 8
                                                    font.weight: Font.Bold
                                                    font.letterSpacing: 0.5
                                                }
                                            }
                                        }
                                        MouseArea {
                                            id: vHover
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: page.selectedVersion = model.id_
                                        }
                                    }
                                }
                            }
                        }

                        Item { implicitHeight: 12 }

                        // Footer actions
                        Row {
                            Layout.alignment: Qt.AlignRight
                            spacing: 8
                            IconButton {
                                variant: "ghost"
                                text: qsTr("Annuler")
                                onClicked: page.back()
                            }
                            IconButton {
                                variant: "primary"
                                iconName: "play"
                                text: qsTr("Créer l'instance")
                                enabled: page.canCreate
                                onClicked: page.created(page.instanceName, page.selectedVersion, page.selectedLoader)
                            }
                        }
                    }

                    // Stub body for non-vanilla tabs
                    Column {
                        visible: page.tabIndex !== 0
                        Layout.leftMargin: 36
                        Layout.rightMargin: 36
                        Layout.fillWidth: true
                        spacing: 6
                        Text {
                            text: qsTr("Cette source n'est pas encore disponible dans BerserkMC. Utilise l'onglet Vanilla en attendant.")
                            color: Theme.textMuted
                            font.family: Theme.fontBody
                            font.pointSize: 11
                            wrapMode: Text.WordWrap
                            width: parent.width
                        }
                    }

                    Item { Layout.fillHeight: true }
                }
            }
        }
    }
}
