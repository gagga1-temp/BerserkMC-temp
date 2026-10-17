// SPDX-License-Identifier: Apache-2.0
// Compact skin selector: a horizontal strip of skin heads + a Classic/Slim
// toggle. Used when creating an offline account and in the account detail.
//
// The parent reads `selectedKey` / `selectedVariant` (or listens to `picked`).

import QtQuick 2.15
import QtQuick.Layouts 1.15

import BerserkMC.Ui 1.0
import "../components" as C

ColumnLayout {
    id: root
    property string selectedKey: ""
    property string selectedVariant: "classic"
    property bool showNone: true
    // Offline profiles may only use the bundled system skins, so the parent
    // can hide imported (file-backed) skins from the strip.
    property bool systemOnly: false
    property string label: qsTr("SKIN")

    signal picked(string key, string variant)

    spacing: 6

    ListModel { id: skinsModel }

    function reload() {
        skinsModel.clear()
        if (typeof App === "undefined") return
        var list = App.skins || []
        for (var i = 0; i < list.length; ++i) {
            var s = list[i]
            // Offline profiles only get the bundled system skins.
            if (root.systemOnly && s.internal !== true) continue
            skinsModel.append({
                key:      s.key || "",
                name:     s.name || s.key || "",
                internal: s.internal === true,
                slim:     s.slim === true,
                classic:  s.classic === true
            })
        }
    }

    function supports(variant) {
        for (var i = 0; i < skinsModel.count; ++i) {
            var s = skinsModel.get(i)
            if (s.key === root.selectedKey)
                return variant === "slim" ? s.slim : s.classic
        }
        return false
    }

    function choose(key) {
        root.selectedKey = key
        // Keep the variant valid for the newly chosen skin.
        if (root.selectedVariant === "slim" && !supports("slim") && supports("classic"))
            root.selectedVariant = "classic"
        root.picked(root.selectedKey, root.selectedVariant)
    }

    function setVariant(v) {
        if (!supports(v)) return
        root.selectedVariant = v
        root.picked(root.selectedKey, root.selectedVariant)
    }

    Component.onCompleted: reload()

    Connections {
        target: typeof App !== "undefined" ? App : null
        function onSkinsChanged() { root.reload() }
    }

    // ----- Header row: label + variant toggle -----
    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Text {
            text: root.label
            color: Theme.textDim
            font.family: Theme.fontBody
            font.pointSize: 9
            font.letterSpacing: 1
            font.weight: Font.DemiBold
        }

        Item { Layout.fillWidth: true }

        Row {
            spacing: 4
            visible: root.selectedKey.length > 0

            Repeater {
                model: [ { v: "classic", label: qsTr("Classique") },
                         { v: "slim",    label: qsTr("Slim") } ]
                delegate: Rectangle {
                    property bool supported: root.supports(modelData.v)
                    property bool active: root.selectedVariant === modelData.v
                    implicitHeight: 22
                    implicitWidth: vLabel.implicitWidth + 16
                    radius: 999
                    color: active ? Theme.accentSoft : (vHover.containsMouse ? Theme.bgElevated : "transparent")
                    border.color: active ? Theme.accentRing : Theme.borderSubtle
                    border.width: 1
                    opacity: supported ? 1 : 0.35
                    Behavior on color { ColorAnimation { duration: Theme.durFast } }

                    Text {
                        id: vLabel
                        anchors.centerIn: parent
                        text: modelData.label
                        color: active ? Theme.accentStrong : Theme.textMuted
                        font.family: Theme.fontBody
                        font.pointSize: 8
                        font.weight: Font.DemiBold
                    }
                    MouseArea {
                        id: vHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.setVariant(modelData.v)
                    }
                }
            }
        }
    }

    // ----- Horizontal strip of skins -----
    Flickable {
        id: strip
        Layout.fillWidth: true
        Layout.preferredHeight: 88
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        contentWidth: stripRow.implicitWidth
        contentHeight: height

        Row {
            id: stripRow
            spacing: 8

            // "Aucun" (no skin) cell
            Rectangle {
                visible: root.showNone
                width: visible ? 60 : 0
                height: 84
                radius: Theme.radiusMd
                color: root.selectedKey.length === 0 ? Theme.accentSoft : (noneHover.containsMouse ? Theme.bgElevated : "transparent")
                border.color: root.selectedKey.length === 0 ? Theme.accentRing : Theme.borderSubtle
                border.width: 1
                Behavior on color { ColorAnimation { duration: Theme.durFast } }

                Column {
                    anchors.centerIn: parent
                    spacing: 2
                    C.Icon { anchors.horizontalCenter: parent.horizontalCenter; name: "offline"; color: Theme.textDim; size: 22 }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: qsTr("Aucun")
                        color: Theme.textMuted
                        font.family: Theme.fontBody
                        font.pointSize: 8
                    }
                }
                MouseArea {
                    id: noneHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.choose("")
                }
            }

            Repeater {
                model: skinsModel
                delegate: Rectangle {
                    width: 60
                    height: 84
                    radius: Theme.radiusMd
                    color: root.selectedKey === model.key
                        ? Theme.accentSoft
                        : (cellHover.containsMouse ? Theme.bgElevated : "transparent")
                    border.color: root.selectedKey === model.key ? Theme.accentRing : Theme.borderSubtle
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: Theme.durFast } }

                    Column {
                        anchors.centerIn: parent
                        spacing: 4
                        C.SkinAvatar {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 44
                            height: 44
                            hasSkin: true
                            source: "image://skins/face/" + encodeURIComponent(model.key) + "/classic?v=" + model.key
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 56
                            horizontalAlignment: Text.AlignHCenter
                            text: model.name
                            elide: Text.ElideRight
                            color: Theme.textMuted
                            font.family: Theme.fontBody
                            font.pointSize: 8
                        }
                    }
                    MouseArea {
                        id: cellHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.choose(model.key)
                    }
                }
            }
        }
    }
}
