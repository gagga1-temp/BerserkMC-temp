// SPDX-License-Identifier: Apache-2.0
// BerserkMC theme tokens — mirrors _mockups/shared.css. Single source of truth
// consumed by every QML view.

pragma Singleton

import QtQuick 2.15

QtObject {
    id: theme

    // ===== Backgrounds =====
    readonly property color bgBase:      Qt.rgba(12/255, 12/255, 14/255, 1)
    readonly property color bgSurface:   Qt.hsla(0,    0,     0.10, 1)
    readonly property color bgElevated:  Qt.hsla(0,    0,     0.15, 1)
    readonly property color bgInput:     Qt.hsla(0,    0,     0.23, 1)
    readonly property color bgInputOff:  Qt.hsla(0,    0,     0.20, 1)
    readonly property color titlebar:    "#161618"
    readonly property color titlebarBorder: "#2a2a30"

    // ===== Borders =====
    readonly property color border:         Qt.hsla(180/360, 0.67, 0.99, 0.20)
    readonly property color borderFocus:    Qt.hsla(180/360, 0.67, 0.99, 0.30)
    readonly property color borderSubtle:   Qt.hsla(180/360, 0.67, 0.99, 0.10)

    // ===== Text =====
    readonly property color textPrimary:  Qt.hsla(180/360, 0.67, 0.99, 0.90)
    readonly property color textMuted:    Qt.hsla(180/360, 0.67, 0.99, 0.75)
    readonly property color textDim:      Qt.hsla(180/360, 0.67, 0.99, 0.50)

    // ===== Accent (vert Berserk par défaut, modifiable via setAccent) =====
    property color accent:       Qt.hsla(129/360, 0.77, 0.43, 0.75)
    property color accentStrong: Qt.hsla(129/360, 0.77, 0.43, 0.92)
    property color accentSoft:   Qt.hsla(129/360, 0.77, 0.43, 0.15)
    property color accentRing:   Qt.hsla(129/360, 0.77, 0.43, 0.35)
    property color accentGlow1:  Qt.hsla(129/360, 0.77, 0.43, 0.20)
    property color accentGlow2:  Qt.hsla(129/360, 0.77, 0.43, 0.12)

    // Derive all six accent variants from a hex string. Call from QML to
    // re-tint the whole UI at runtime.
    function setAccent(hex) {
        // NOTE: QML has no Qt.color(); the only built-in string→color
        // conversion is assigning to a color property. From a singleton
        // function we therefore parse "#RGB"/"#RRGGBB" by hand.
        if (typeof hex !== "string" || hex.length === 0) return
        var h = hex.charAt(0) === "#" ? hex.substring(1) : hex
        if (h.length === 3) {
            h = h.charAt(0) + h.charAt(0) + h.charAt(1) + h.charAt(1) + h.charAt(2) + h.charAt(2)
        }
        if (h.length !== 6) return
        var r = parseInt(h.substring(0, 2), 16) / 255
        var g = parseInt(h.substring(2, 4), 16) / 255
        var b = parseInt(h.substring(4, 6), 16) / 255
        if (isNaN(r) || isNaN(g) || isNaN(b)) return
        accent       = Qt.rgba(r, g, b, 0.75)
        accentStrong = Qt.rgba(r, g, b, 0.92)
        accentSoft   = Qt.rgba(r, g, b, 0.15)
        accentRing   = Qt.rgba(r, g, b, 0.35)
        accentGlow1  = Qt.rgba(r, g, b, 0.20)
        accentGlow2  = Qt.rgba(r, g, b, 0.12)
    }

    readonly property color accentYellow: Qt.hsla( 41/360, 0.99, 0.59, 0.75)
    readonly property color accentRed:    Qt.hsla(  4/360, 1.00, 0.71, 0.75)

    // ===== Radius =====
    readonly property real radiusSm:  6
    readonly property real radiusMd:  10
    readonly property real radiusLg:  14

    // ===== Spacing scale =====
    readonly property real space1:  4
    readonly property real space2:  8
    readonly property real space3:  12
    readonly property real space4:  16
    readonly property real space5:  24
    readonly property real space6:  32

    // ===== Typography =====
    readonly property string fontBody:   "DM Sans"
    readonly property string fontBrand:  "Caveat"
    readonly property string fontMono:   "VT323"

    readonly property int fontSizeXs:    11
    readonly property int fontSizeSm:    13
    readonly property int fontSizeMd:    14
    readonly property int fontSizeLg:    16
    readonly property int fontSizeXl:    20
    readonly property int fontSizeBrand: 24
    readonly property int fontSize2xl:   28

    readonly property int weightLight:  400
    readonly property int weightMedium: 600
    readonly property int weightHeavy:  800

    // ===== Motion =====
    // Non-readonly so the Settings "Animations" toggle can zero them at runtime.
    property int durFast:   140
    property int durMd:     220
    property int durSlow:   400
    // Easing alias used by Behaviors throughout
    readonly property int easing:    Easing.OutCubic
}
