// SPDX-License-Identifier: Apache-2.0
// Toolbar / sidebar button with optional icon + label. Variants:
//   - "ghost"   (default — transparent until hover)
//   - "filled"  (always tinted)
//   - "primary" (accent)

import QtQuick 2.15
import QtQuick.Layouts 1.15

import BerserkMC.Ui 1.0

Rectangle {
    id: root
    property string text: ""
    property string iconName: ""
    property string variant: "ghost"   // ghost | filled | primary | danger
    property bool dense: false
    property bool dangerOnHover: variant === "danger"
    signal clicked()

    implicitHeight: dense ? 28 : 36
    implicitWidth: row.implicitWidth + (dense ? 16 : 24)
    radius: Theme.radiusMd

    // Item.enabled is inherited; dim disabled buttons so the state is obvious.
    opacity: enabled ? 1 : 0.45
    Behavior on opacity { NumberAnimation { duration: Theme.durFast } }

    color: {
        if (variant === "primary")
            return hover.containsMouse ? Theme.accent : Theme.accentSoft
        if (variant === "filled")
            return hover.containsMouse ? Theme.bgInputOff : Theme.bgElevated
        if (variant === "danger" && hover.containsMouse)
            return Theme.accentRed
        return hover.containsMouse ? Theme.bgElevated : "transparent"
    }
    border.color: {
        if (variant === "primary")
            return Theme.accentRing
        if (variant === "filled" || (variant === "ghost" && hover.containsMouse))
            return hover.containsMouse ? Theme.border : Theme.borderSubtle
        if (variant === "danger" && hover.containsMouse)
            return Theme.accentRed
        return "transparent"
    }
    border.width: 1

    Behavior on color  { ColorAnimation { duration: Theme.durFast } }
    Behavior on border.color { ColorAnimation { duration: Theme.durFast } }
    Behavior on scale { NumberAnimation { duration: Theme.durFast; easing.type: Easing.OutCubic } }
    scale: hover.pressed ? 0.97 : 1

    RowLayout {
        id: row
        anchors.centerIn: parent
        // Never wider than the button itself: lets the label elide instead of
        // spilling out when the button is squeezed (e.g. a narrow detail panel).
        width: Math.min(implicitWidth, Math.max(0, root.width - 12))
        spacing: 8

        Icon {
            visible: root.iconName.length
            name: root.iconName
            color: textRef.color
            size: root.dense ? 14 : 16
        }
        Text {
            id: textRef
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            text: root.text
            visible: text.length
            elide: Text.ElideRight
            font.family: Theme.fontBody
            font.pointSize: root.dense ? 9 : 10
            font.weight: Font.DemiBold
            color: {
                if (variant === "primary")
                    return hover.containsMouse ? "white" : Theme.accentStrong
                if (variant === "danger" && hover.containsMouse)
                    return "white"
                return hover.containsMouse ? Theme.textPrimary : Theme.textMuted
            }
            Behavior on color { ColorAnimation { duration: Theme.durFast } }
        }
    }

    MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
