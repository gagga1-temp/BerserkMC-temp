// SPDX-License-Identifier: Apache-2.0
// Skins view: manage the local skin library (import PNG, preview, delete) and
// assign a skin to an account. The skin is stored per account (in
// accounts.json) and shown by the launcher itself. Offline profiles are limited
// to the bundled system skins; imported skins are reserved for online profiles.

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

import BerserkMC.Ui 1.0
import "../components"

Rectangle {
    id: page
    color: Theme.bgBase

    readonly property string viewTitle: "SKINS"
    signal back()

    // ===== Library model =====
    ListModel { id: skinsModel }

    property string selectedKey: ""
    property string selectedVariant: "classic"

    function reload() {
        var keep = page.selectedKey
        skinsModel.clear()
        if (typeof App === "undefined") return
        var list = App.skins || []
        for (var i = 0; i < list.length; ++i) {
            var s = list[i]
            skinsModel.append({
                key:      s.key || "",
                name:     s.name || s.key || "",
                internal: s.internal === true,
                slim:     s.slim === true,
                classic:  s.classic === true
            })
        }
        if (keep.length === 0 || indexOfKey(keep) < 0) {
            page.selectedKey = skinsModel.count > 0 ? skinsModel.get(0).key : ""
            page.selectedVariant = "classic"
        } else {
            page.selectedKey = keep
        }
    }

    function indexOfKey(key) {
        for (var i = 0; i < skinsModel.count; ++i)
            if (skinsModel.get(i).key === key) return i
        return -1
    }
    function current() {
        var i = indexOfKey(page.selectedKey)
        return i < 0 ? null : skinsModel.get(i)
    }
    function currentSupports(variant) {
        var c = current()
        if (!c) return false
        return variant === "slim" ? c.slim : c.classic
    }
    function setVariant(v) {
        if (currentSupports(v)) page.selectedVariant = v
    }
    // True when the selected library skin is a bundled system skin (imported
    // ones can only go to online profiles).
    function currentIsSystem() {
        var c = current()
        return !!c && c.internal === true
    }

    // ===== Accounts (assign targets) =====
    ListModel { id: accountsModel }
    function reloadAccounts() {
        accountsModel.clear()
        if (typeof App === "undefined") return
        var list = App.accounts || []
        for (var i = 0; i < list.length; ++i) {
            var a = list[i]
            accountsModel.append({
                internalId: a.internalId || "",
                name:       a.displayName || "(sans nom)",
                initial:    (a.displayName || "?").charAt(0).toUpperCase(),
                skinKey:    a.skinKey || "",
                skinVariant:(a.skinVariant || "classic"),
                hasSkin:    a.hasSkin === true,
                offline:    a.kind === "Offline"
            })
        }
    }

    function accountAvatar(id, hasSkin) {
        return hasSkin ? ("image://skins/account/" + id + "?v=" + id) : ""
    }

    function applyToAccount(internalId, currentKey, accountSkinKey) {
        if (typeof App === "undefined") return
        if (currentKey.length > 0 && currentKey === accountSkinKey)
            App.clearAccountSkin(internalId)     // toggle off
        else
            App.setAccountSkin(internalId, page.selectedKey, page.selectedVariant)
    }

    Component.onCompleted: { reload(); reloadAccounts() }

    Connections {
        target: typeof App !== "undefined" ? App : null
        function onSkinsChanged()    { page.reload() }
        function onAccountsChanged() { page.reloadAccounts() }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        PageHeader {
            Layout.fillWidth: true
            iconName: "cube"
            title: qsTr("Skins")
            subtitle: qsTr("%1 skin(s) — personnalise l'apparence de tes comptes").arg(skinsModel.count)
            onBack: page.back()
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            // ===== Library =====
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.margins: 20
                spacing: 14

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    IconButton {
                        variant: "primary"
                        iconName: "upload"
                        text: qsTr("Importer un skin")
                        onClicked: if (typeof App !== "undefined") App.importSkin()
                    }
                    IconButton {
                        variant: "ghost"
                        iconName: "folder"
                        text: qsTr("Ouvrir le dossier")
                        onClicked: if (typeof App !== "undefined") App.openSkinsFolder()
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: qsTr("PNG 64×64 · Classique ou Slim")
                        color: Theme.textDim
                        font.family: Theme.fontBody
                        font.pointSize: 9
                    }
                }

                GridView {
                    id: grid
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    cellWidth: 116
                    cellHeight: 148
                    boundsBehavior: Flickable.StopAtBounds
                    model: skinsModel

                    delegate: Item {
                        width: grid.cellWidth
                        height: grid.cellHeight

                        Rectangle {
                            id: card
                            anchors.fill: parent
                            anchors.margins: 5
                            radius: Theme.radiusMd
                            color: page.selectedKey === model.key
                                ? Theme.accentSoft
                                : (cellHover.containsMouse ? Theme.bgElevated : Theme.bgSurface)
                            border.color: page.selectedKey === model.key ? Theme.accentRing : Theme.borderSubtle
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: Theme.durFast } }

                            Column {
                                anchors.centerIn: parent
                                spacing: 8

                                Image {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: 68; height: 68
                                    source: "image://skins/list/" + encodeURIComponent(model.key) + "?v=" + model.key
                                    smooth: false
                                    mipmap: false
                                    cache: false
                                    fillMode: Image.PreserveAspectFit
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: 96
                                    horizontalAlignment: Text.AlignHCenter
                                    text: model.name
                                    elide: Text.ElideRight
                                    color: Theme.textPrimary
                                    font.family: Theme.fontBody
                                    font.pointSize: 10
                                    font.weight: Font.DemiBold
                                }
                                Rectangle {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    visible: model.internal
                                    implicitHeight: 16
                                    implicitWidth: sysLbl.implicitWidth + 12
                                    radius: 4
                                    color: Theme.bgInput
                                    Text {
                                        id: sysLbl
                                        anchors.centerIn: parent
                                        text: qsTr("SYSTÈME")
                                        color: Theme.textMuted
                                        font.family: Theme.fontBody
                                        font.pointSize: 7
                                        font.weight: Font.Bold
                                    }
                                }
                            }

                            MouseArea {
                                id: cellHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: page.selectedKey = model.key
                                onDoubleClicked: if (accountsModel.count > 0
                                                     && (page.currentIsSystem() || !accountsModel.get(0).offline))
                                                     page.applyToAccount(accountsModel.get(0).internalId, page.selectedKey, "")
                            }
                        }
                    }
                }
            }

            // ===== Detail / actions =====
            Rectangle {
                Layout.preferredWidth: 320
                Layout.fillHeight: true
                color: Theme.bgSurface

                Rectangle {
                    anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                    width: 1
                    color: Theme.borderSubtle
                }

                ScrollView {
                    id: detailScroll
                    anchors.fill: parent
                    anchors.margins: 20
                    clip: true
                    contentWidth: availableWidth

                    ColumnLayout {
                        width: detailScroll.availableWidth
                        spacing: 18

                        // Preview
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 168
                            radius: Theme.radiusLg
                            color: Theme.bgElevated
                            border.color: Theme.borderSubtle
                            border.width: 1

                            Image {
                                anchors.centerIn: parent
                                width: 132; height: 132
                                source: page.current()
                                    ? ("image://skins/list/" + encodeURIComponent(page.selectedKey) + "?v=" + page.selectedKey)
                                    : ""
                                smooth: false
                                mipmap: false
                                cache: false
                                fillMode: Image.PreserveAspectFit
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: page.current() ? page.current().name : qsTr("Aucun skin sélectionné")
                            color: Theme.textPrimary
                            font.family: Theme.fontBody
                            font.pointSize: 18
                            font.weight: Font.Bold
                            elide: Text.ElideRight
                        }

                        // Variant toggle
                        Row {
                            spacing: 6
                            visible: page.current() !== null
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: qsTr("MODÈLE")
                                color: Theme.textDim
                                font.family: Theme.fontBody
                                font.pointSize: 9
                                font.letterSpacing: 1
                                font.weight: Font.DemiBold
                            }
                            Repeater {
                                model: [ { v: "classic", label: qsTr("Classique") },
                                         { v: "slim",    label: qsTr("Slim") } ]
                                delegate: Rectangle {
                                    property bool supported: page.currentSupports(modelData.v)
                                    property bool active: page.selectedVariant === modelData.v
                                    implicitHeight: 26
                                    implicitWidth: vLbl.implicitWidth + 18
                                    radius: 999
                                    color: active ? Theme.accentSoft : "transparent"
                                    border.color: active ? Theme.accentRing : Theme.borderSubtle
                                    border.width: 1
                                    opacity: supported ? 1 : 0.35
                                    Text {
                                        id: vLbl
                                        anchors.centerIn: parent
                                        text: modelData.label
                                        color: active ? Theme.accentStrong : Theme.textMuted
                                        font.family: Theme.fontBody
                                        font.pointSize: 9
                                        font.weight: Font.DemiBold
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: page.setVariant(modelData.v)
                                    }
                                }
                            }
                        }

                        Rectangle { Layout.fillWidth: true; height: 1; color: Theme.borderSubtle }

                        // Assign to accounts
                        Column {
                            Layout.fillWidth: true
                            spacing: 8

                            Text {
                                text: qsTr("APPLIQUER À UN COMPTE")
                                color: Theme.textDim
                                font.family: Theme.fontBody
                                font.pointSize: 9
                                font.letterSpacing: 1
                                font.weight: Font.DemiBold
                            }

                            Text {
                                visible: accountsModel.count === 0
                                text: qsTr("Aucun compte. Crée un profil hors-ligne dans « Comptes ».")
                                color: Theme.textMuted
                                font.family: Theme.fontBody
                                font.pointSize: 10
                                wrapMode: Text.WordWrap
                                width: parent.width
                            }

                            Text {
                                visible: !page.currentIsSystem() && page.current() !== null
                                text: qsTr("Skin importé : réservé aux comptes en ligne.")
                                color: Theme.textDim
                                font.family: Theme.fontBody
                                font.pointSize: 9
                                wrapMode: Text.WordWrap
                                width: parent.width
                            }

                            Repeater {
                                model: accountsModel
                                delegate: Rectangle {
                                    width: parent.width
                                    implicitHeight: 52
                                    radius: Theme.radiusMd
                                    property bool isCurrent: model.skinKey === page.selectedKey && page.selectedKey.length > 0
                                    // Imported skins are reserved for online profiles.
                                    property bool blocked: !page.currentIsSystem() && model.offline
                                    enabled: !blocked
                                    opacity: blocked ? 0.45 : 1
                                    color: isCurrent ? Theme.accentSoft : (acctHover.containsMouse ? Theme.bgElevated : Theme.bgInput)
                                    border.color: isCurrent ? Theme.accentRing : Theme.borderSubtle
                                    border.width: 1
                                    Behavior on color { ColorAnimation { duration: Theme.durFast } }

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: 8
                                        spacing: 10

                                        SkinAvatar {
                                            Layout.preferredWidth: 34
                                            Layout.preferredHeight: 34
                                            hasSkin: model.hasSkin
                                            source: page.accountAvatar(model.internalId, model.hasSkin)
                                            fallbackText: model.initial
                                        }
                                        Text {
                                            Layout.fillWidth: true
                                            text: model.name
                                            color: Theme.textPrimary
                                            font.family: Theme.fontBody
                                            font.pointSize: 11
                                            font.weight: Font.DemiBold
                                            elide: Text.ElideRight
                                        }
                                        Text {
                                            visible: blocked
                                            text: qsTr("HORS-LIGNE")
                                            color: Theme.textDim
                                            font.family: Theme.fontBody
                                            font.pointSize: 7
                                            font.weight: Font.Bold
                                        }
                                        Icon {
                                            visible: isCurrent
                                            name: "star"
                                            color: Theme.accentStrong
                                            size: 14
                                        }
                                    }

                                    MouseArea {
                                        id: acctHover
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: blocked ? Qt.ForbiddenCursor : Qt.PointingHandCursor
                                        onClicked: if (!blocked)
                                                       page.applyToAccount(model.internalId, page.selectedKey, model.skinKey)
                                    }
                                }
                            }
                        }

                        Item { Layout.fillHeight: true }

                        IconButton {
                            Layout.fillWidth: true
                            variant: "danger"
                            iconName: "trash"
                            text: qsTr("Supprimer ce skin")
                            enabled: page.current() !== null && !page.current().internal
                            onClicked: {
                                if (page.current() && typeof App !== "undefined")
                                    App.deleteSkin(page.selectedKey)
                            }
                        }
                        Text {
                            Layout.fillWidth: true
                            visible: page.current() !== null && page.current().internal
                            text: qsTr("Les skins système ne peuvent pas être supprimés.")
                            color: Theme.textDim
                            font.family: Theme.fontBody
                            font.pointSize: 9
                            wrapMode: Text.WordWrap
                        }
                    }
                }
            }
        }
    }
}
