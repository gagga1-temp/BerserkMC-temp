// SPDX-License-Identifier: Apache-2.0
// One instance tile in the library grid.

import QtQuick 2.15

import BerserkMC.Ui 1.0

Rectangle {
    id: card
    property string name: ""
    property string sub: ""
    property string iconSource: "qrc:/icons/multimc/256x256/minecraft.png"
    property bool selected: false
    property bool addTile: false

    signal clicked()
    signal doubleClicked()

    implicitWidth: 150
    implicitHeight: 150
    radius: Theme.radiusLg
    color: Theme.bgSurface
    antialiasing: true

    border.color: card.selected
        ? Theme.accentRing
        : (hover.containsMouse ? Theme.border : Theme.borderSubtle)
    border.width: card.selected ? 2 : 1

    Behavior on border.color { ColorAnimation { duration: Theme.durFast } }
    Behavior on color        { ColorAnimation { duration: Theme.durFast } }
    Behavior on scale        { NumberAnimation { duration: Theme.durMd; easing.type: Easing.OutCubic } }
    Behavior on y            { NumberAnimation { duration: Theme.durMd; easing.type: Easing.OutCubic } }

    // Dashed style for the "Add" tile
    Rectangle {
        anchors.fill: parent
        visible: card.addTile
        color: "transparent"
        radius: Theme.radiusLg
        border.width: 1
        border.color: hover.containsMouse ? Theme.accentRing : Theme.borderSubtle
        // Approximate dashed: superimpose tiny rects? Skip — keep simple solid w/ subtle look.
    }

    scale: hover.containsMouse ? 1.025 : 1.0

    // Selection halo (outer glow)
    Rectangle {
        anchors.fill: parent
        anchors.margins: -4
        radius: Theme.radiusLg + 4
        color: "transparent"
        border.color: card.selected ? Theme.accentGlow2 : "transparent"
        border.width: 4
        visible: card.selected
        z: -1
    }

    // Icon area (top 65%)
    Item {
        id: iconArea
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: parent.height * 0.65

        // Real Minecraft icon (PNG from the bundled multimc icon set). No glow,
        // no tint — preserve the original art exactly as Mojang/MultiMC ships it.
        Image {
            id: iconImg
            anchors.centerIn: parent
            visible: !card.addTile
            source: card.iconSource
            sourceSize.width: 128
            sourceSize.height: 128
            width: parent.height * 0.78
            height: parent.height * 0.78
            fillMode: Image.PreserveAspectFit
            smooth: true
        }

        // Add tile fallback (centered plus glyph)
        Icon {
            anchors.centerIn: parent
            visible: card.addTile
            name: "plus"
            color: hover.containsMouse ? Theme.accentStrong : Theme.textDim
            size: 40
        }
    }

    // Subtle divider between icon area and info text (avoids the rounded-clip
    // headache — we just keep the card single-color and let the parent's
    // radius cover all four corners naturally).
    Rectangle {
        anchors.top: iconArea.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        height: 1
        color: Theme.borderSubtle
        visible: !card.addTile
    }

    // Info text (bottom region)
    Column {
        anchors.top: iconArea.bottom
        anchors.topMargin: 8
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 2

        Text {
            width: parent.width
            text: card.name
            color: Theme.textPrimary
            font.family: Theme.fontBody
            font.pointSize: 10
            font.weight: Font.DemiBold
            elide: Text.ElideRight
            horizontalAlignment: card.addTile ? Text.AlignHCenter : Text.AlignLeft
        }
        Text {
            width: parent.width
            text: card.sub
            color: Theme.textDim
            font.family: Theme.fontBody
            font.pointSize: 8
            visible: text.length
            elide: Text.ElideRight
        }
    }

    MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: card.clicked()
        onDoubleClicked: card.doubleClicked()
    }
}
