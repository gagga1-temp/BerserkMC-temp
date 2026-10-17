// SPDX-License-Identifier: Apache-2.0
// Minecraft head avatar. Renders the head (face + hat) of a skin served by the
// cpp "skins" image provider, or falls back to a coloured initial when the
// account has no skin assigned.
//
//   SkinAvatar { source: "image://skins/account/<id>"; hasSkin: true; fallbackText: "K" }
//   SkinAvatar { circle: true; fallbackText: "K" }

import QtQuick 2.15

import BerserkMC.Ui 1.0

Rectangle {
    id: root
    property string source: ""
    property bool hasSkin: false
    property string fallbackText: "?"
    property bool circle: false
    property color fallbackColor: Theme.accentStrong
    property color fallbackBg: Theme.accentSoft

    radius: circle ? Math.min(width, height) / 2 : Theme.radiusSm

    color: hasSkin ? "transparent" : fallbackBg
    border.color: hasSkin ? Theme.borderSubtle : "transparent"
    border.width: hasSkin ? 1 : 0
    clip: true

    Image {
        anchors.fill: parent
        anchors.margins: root.hasSkin ? 1 : 0
        source: root.hasSkin ? root.source : ""
        visible: root.hasSkin
        fillMode: Image.PreserveAspectFit
        smooth: false
        mipmap: false
        cache: false
    }

    Text {
        anchors.centerIn: parent
        visible: !root.hasSkin
        text: root.fallbackText
        color: root.fallbackColor
        font.family: Theme.fontBody
        font.pointSize: Math.max(8, Math.round(root.height * 0.36))
        font.weight: Font.Bold
    }
}
