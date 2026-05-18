// SPDX-License-Identifier: Apache-2.0
// Single-line icon helper. Loads an SVG from qrc:/qml/icons/<name>.svg and
// tints it to `color` via ColorOverlay (the bundled SVGs are stroked white).

import QtQuick 2.15
import QtGraphicalEffects 1.15

Item {
    id: root
    property string name: ""
    property color color: "white"
    property real size: 18

    implicitWidth: size
    implicitHeight: size

    Image {
        id: img
        anchors.fill: parent
        source: root.name.length ? "qrc:/qml/icons/" + root.name + ".svg" : ""
        sourceSize.width: root.size * 2
        sourceSize.height: root.size * 2
        smooth: true
        visible: false
    }
    ColorOverlay {
        anchors.fill: img
        source: img
        color: root.color
    }
}
