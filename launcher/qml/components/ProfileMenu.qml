// SPDX-License-Identifier: Apache-2.0
// Profile selector: a pill trigger (round avatar + pseudo + status badge +
// chevron) that opens a dropdown listing every profile. The active profile is
// marked with a check; clicking a row switches the active profile. A footer
// row creates a new profile — OFFLINE only: Microsoft accounts are added from
// the Comptes page, never from this shortcut.
//
// The badge is driven by `kind`, so an ONLINE profile renders as a solid green
// pill as soon as one exists.

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

import BerserkMC.Ui 1.0

Item {
    id: root

    // [{ internalId, name, initial, kind, hasSkin }]
    property var profiles: []
    property string activeId: ""

    signal profileActivated(string internalId)
    signal profileCreated(string playerName)
    signal accountManagementRequested()

    implicitWidth: triggerContent.implicitWidth + 20
    implicitHeight: 32

    // Per-profile avatar tint, derived deterministically from the pseudo so a
    // given profile always keeps the same colour.
    readonly property var palette: [
        { bg: "#1f4029", fg: "#8fd6a4" },
        { bg: "#16324f", fg: "#7fb4ef" },
        { bg: "#322a4d", fg: "#b6a6f0" },
        { bg: "#4a2740", fg: "#eb9fd0" },
        { bg: "#4a3a18", fg: "#e7c46a" },
        { bg: "#4a2626", fg: "#ef8f8f" },
        { bg: "#12403f", fg: "#5fd0c9" },
        { bg: "#153d4a", fg: "#79cbe8" }
    ]
    function colorIndex(s) {
        var h = 5381
        for (var i = 0; i < s.length; ++i)
            h = ((h << 5) + h + s.charCodeAt(i)) >>> 0
        return h % palette.length
    }
    function avatarBg(s) { return palette[colorIndex(s)].bg }
    function avatarFg(s) { return palette[colorIndex(s)].fg }

    function activeProfile() {
        for (var i = 0; i < profiles.length; ++i)
            if (profiles[i].internalId === activeId) return profiles[i]
        return profiles.length ? profiles[0] : null
    }
    function skinSource(p) {
        return p && p.hasSkin
            ? ("image://skins/account/" + p.internalId + "?v=" + p.internalId)
            : ""
    }

    // Snapshot of `profiles` for the popup's ListView.
    ListModel { id: rows }
    function rebuildRows() {
        rows.clear()
        for (var i = 0; i < profiles.length; ++i) {
            var p = profiles[i]
            rows.append({
                internalId: p.internalId,
                name: p.name,
                initial: p.initial,
                kind: p.kind,
                hasSkin: p.hasSkin === true
            })
        }
    }
    onProfilesChanged: rebuildRows()
    Component.onCompleted: rebuildRows()

    // ===== Inline components =====

    // Status badge: OFFLINE = discreet green, ONLINE = solid green.
    component StatusBadge: Rectangle {
        id: badge
        property string kind: "Offline"
        readonly property bool online: kind === "Microsoft"
        implicitHeight: 18
        implicitWidth: badgeLabel.implicitWidth + 12
        radius: 4
        color: online ? Theme.accentStrong : Theme.accentSoft
        Behavior on color { ColorAnimation { duration: Theme.durFast } }

        Text {
            id: badgeLabel
            anchors.centerIn: parent
            text: badge.online ? "ONLINE" : "OFFLINE"
            color: badge.online ? "white" : Theme.accentStrong
            font.family: Theme.fontBody
            font.pointSize: 8
            font.letterSpacing: 0.5
            font.weight: Font.Bold
        }
    }

    // Round "add" avatar drawn as a ring of dots (dashed look) + a plus icon.
    component DashedAddCircle: Item {
        id: dc
        implicitWidth: 28
        implicitHeight: 28

        Repeater {
            model: 14
            delegate: Rectangle {
                width: 2.4; height: 2.4; radius: 1.2
                color: Theme.textDim
                x: dc.width / 2 + (dc.width / 2 - 3) * Math.cos(index * 2 * Math.PI / 14) - width / 2
                y: dc.height / 2 + (dc.height / 2 - 3) * Math.sin(index * 2 * Math.PI / 14) - height / 2
            }
        }
        Icon {
            anchors.centerIn: parent
            name: "plus"
            size: 13
            color: Theme.textMuted
        }
    }

    // ===== Trigger =====
    Rectangle {
        id: trigger
        anchors.fill: parent
        radius: 999
        color: (triggerMouse.containsMouse || menu.opened) ? Theme.bgInputOff : Theme.bgElevated
        border.color: (triggerMouse.containsMouse || menu.opened) ? Theme.border : Theme.borderSubtle
        border.width: 1
        Behavior on color { ColorAnimation { duration: Theme.durFast } }
        Behavior on border.color { ColorAnimation { duration: Theme.durFast } }

        RowLayout {
            id: triggerContent
            anchors.centerIn: parent
            spacing: 8

            SkinAvatar {
                width: 22; height: 22; circle: true
                hasSkin: root.activeProfile() !== null && root.activeProfile().hasSkin
                source: root.skinSource(root.activeProfile())
                fallbackText: root.activeProfile() ? root.activeProfile().initial : "?"
                fallbackBg: Theme.accentSoft
                fallbackColor: Theme.accentStrong
            }
            Text {
                text: root.activeProfile() ? root.activeProfile().name : qsTr("Aucun profil")
                color: Theme.textPrimary
                font.family: Theme.fontBody
                font.pointSize: 10
                font.weight: Font.DemiBold
            }
            StatusBadge {
                kind: root.activeProfile() ? root.activeProfile().kind : "Offline"
            }
            Icon {
                name: "chevron-down"
                size: 14
                color: Theme.textMuted
                rotation: menu.opened ? 180 : 0
                Behavior on rotation { NumberAnimation { duration: Theme.durFast; easing.type: Easing.OutCubic } }
            }
        }

        MouseArea {
            id: triggerMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: menu.opened ? menu.close() : menu.open()
        }
    }

    // ===== Dropdown =====
    Popup {
        id: menu
        parent: root
        width: 300
        x: root.width - width
        y: root.height + 8
        padding: 0
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        property bool creating: false
        property int navIndex: 0

        background: Rectangle {
            color: Theme.bgElevated
            radius: 12
            border.color: Theme.borderSubtle
            border.width: 1
        }
        // Modal so an outside click is swallowed (and closes) instead of
        // reopening the menu through the trigger. Fully transparent — no dim.
        Overlay.modal: Rectangle { color: "transparent" }

        function indexOfActive() {
            for (var i = 0; i < rows.count; ++i)
                if (rows.get(i).internalId === root.activeId) return i
            return 0
        }
        function move(delta) {
            var n = rows.count + 1   // profiles + the "create" row
            navIndex = (navIndex + delta + n) % n
        }
        function activate() {
            if (navIndex >= rows.count) { beginCreate(); return }
            var it = rows.get(navIndex)
            if (it) { menu.close(); root.profileActivated(it.internalId) }
        }
        function beginCreate() {
            creating = true
            newName.text = ""
            errorText.text = ""
            Qt.callLater(function() { newName.forceActiveFocus() })
        }
        function tryCreate() {
            var name = newName.text.trim()
            if (name.length === 0) {
                errorText.text = qsTr("Entrez un pseudo")
                return
            }
            for (var i = 0; i < root.profiles.length; ++i) {
                if ((root.profiles[i].name || "").toLowerCase() === name.toLowerCase()) {
                    errorText.text = qsTr("Ce pseudo existe déjà")
                    return
                }
            }
            root.profileCreated(name)
            creating = false
            newName.text = ""
            errorText.text = ""
            Qt.callLater(function() { content.forceActiveFocus() })
        }
        onOpened: {
            rebuildRows()
            navIndex = indexOfActive()
            creating = false
            newName.text = ""
            errorText.text = ""
            content.forceActiveFocus()
        }
        onClosed: {
            creating = false
            newName.text = ""
            errorText.text = ""
        }

        contentItem: ColumnLayout {
            id: content
            spacing: 0
            focus: true
            Keys.onUpPressed:   if (!menu.creating) menu.move(-1)
            Keys.onDownPressed: if (!menu.creating) menu.move(1)
            Keys.onReturnPressed: if (!menu.creating) menu.activate()
            Keys.onEnterPressed:  if (!menu.creating) menu.activate()

            // --- header: "Vos profils" + manage button ---
            Item {
                Layout.fillWidth: true
                implicitHeight: 38

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("Vos profils")
                    color: Theme.textDim
                    font.family: Theme.fontBody
                    font.pointSize: 9
                    font.letterSpacing: 1
                    font.weight: Font.DemiBold
                }

                Rectangle {
                    id: manageBtn
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    width: 26; height: 26
                    radius: 6
                    color: manageHover.containsMouse ? Theme.bgInputOff : "transparent"
                    Behavior on color { ColorAnimation { duration: Theme.durFast } }

                    Icon {
                        anchors.centerIn: parent
                        name: "gear"
                        size: 14
                        color: manageHover.containsMouse ? Theme.textPrimary : Theme.textDim
                    }
                    MouseArea {
                        id: manageHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { menu.close(); root.accountManagementRequested() }
                    }
                }
            }

            // --- profile list ---
            ListView {
                id: listView
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(contentHeight, 264)
                model: rows
                spacing: 2
                clip: true
                interactive: contentHeight > height
                boundsBehavior: Flickable.StopAtBounds

                delegate: Rectangle {
                    width: ListView.view.width
                    height: 44
                    radius: 8
                    readonly property bool isActive: model.internalId === root.activeId
                    color: isActive ? Theme.accentSoft
                                    : ((rowMouse.containsMouse || menu.navIndex === index)
                                        ? Theme.bgElevated : "transparent")
                    border.color: isActive ? Theme.accentRing : "transparent"
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: Theme.durFast } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 10

                        SkinAvatar {
                            width: 28; height: 28; circle: true
                            hasSkin: model.hasSkin
                            source: model.hasSkin
                                ? ("image://skins/account/" + model.internalId + "?v=" + model.internalId)
                                : ""
                            fallbackText: model.initial
                            fallbackBg: root.avatarBg(model.name)
                            fallbackColor: root.avatarFg(model.name)
                        }
                        Text {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            text: model.name
                            elide: Text.ElideRight
                            color: Theme.textPrimary
                            font.family: Theme.fontBody
                            font.pointSize: 11
                            font.weight: Font.DemiBold
                        }
                        StatusBadge { kind: model.kind }
                        Icon {
                            visible: isActive
                            name: "check"
                            size: 16
                            color: Theme.accentStrong
                        }
                    }

                    MouseArea {
                        id: rowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { menu.close(); root.profileActivated(model.internalId) }
                    }
                }
            }

            // --- separator ---
            Rectangle {
                Layout.fillWidth: true
                Layout.leftMargin: 8
                Layout.rightMargin: 8
                Layout.topMargin: 4
                implicitHeight: 1
                color: Theme.borderSubtle
            }

            // --- create area ---
            Item {
                Layout.fillWidth: true
                implicitHeight: menu.creating ? (createForm.implicitHeight + 10) : 46

                // Collapsed: "+ Créer un profil"
                Rectangle {
                    id: createRow
                    visible: !menu.creating
                    anchors.fill: parent
                    anchors.margins: 4
                    radius: 8
                    color: (createHover.containsMouse || menu.navIndex === rows.count)
                        ? Theme.bgElevated : "transparent"
                    Behavior on color { ColorAnimation { duration: Theme.durFast } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 10
                        spacing: 10
                        DashedAddCircle { Layout.alignment: Qt.AlignVCenter }
                        Text {
                            Layout.fillWidth: true
                            text: qsTr("Créer un profil hors-ligne")
                            color: Theme.textMuted
                            font.family: Theme.fontBody
                            font.pointSize: 11
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }
                    }
                    MouseArea {
                        id: createHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: menu.beginCreate()
                    }
                }

                // Expanded: pseudo field + "Créer"
                ColumnLayout {
                    id: createForm
                    visible: menu.creating
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    anchors.topMargin: 4
                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        DashedAddCircle { Layout.alignment: Qt.AlignVCenter }

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 34
                            radius: 8
                            color: Theme.bgInput
                            border.color: newName.activeFocus ? Theme.accentRing : Theme.borderSubtle
                            border.width: 1
                            Behavior on border.color { ColorAnimation { duration: Theme.durFast } }

                            TextField {
                                id: newName
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                placeholderText: qsTr("Pseudo")
                                placeholderTextColor: Theme.textDim
                                color: Theme.textPrimary
                                font.family: Theme.fontBody
                                font.pointSize: 11
                                maximumLength: 16
                                background: null
                                verticalAlignment: TextInput.AlignVCenter
                                validator: RegExpValidator { regExp: /^[a-zA-Z0-9_]{0,16}$/ }
                                onTextChanged: errorText.text = ""
                                onAccepted: menu.tryCreate()
                            }
                        }

                        Rectangle {
                            implicitHeight: 34
                            implicitWidth: createLabel.implicitWidth + 22
                            radius: 8
                            color: createBtnHover.containsMouse ? Theme.accent : Theme.accentSoft
                            border.color: Theme.accentRing
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: Theme.durFast } }

                            Text {
                                id: createLabel
                                anchors.centerIn: parent
                                text: qsTr("Créer")
                                color: createBtnHover.containsMouse ? "white" : Theme.accentStrong
                                font.family: Theme.fontBody
                                font.pointSize: 10
                                font.weight: Font.Bold
                            }
                            MouseArea {
                                id: createBtnHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: menu.tryCreate()
                            }
                        }
                    }

                    Text {
                        id: errorText
                        Layout.fillWidth: true
                        text: ""
                        visible: text.length > 0
                        color: Theme.accentRed
                        font.family: Theme.fontBody
                        font.pointSize: 9
                        wrapMode: Text.WordWrap
                    }
                }
            }
        }
    }
}
