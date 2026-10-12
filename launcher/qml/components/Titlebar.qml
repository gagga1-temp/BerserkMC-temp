// SPDX-License-Identifier: Apache-2.0
// Reusable BerserkMC titlebar:
//   - β brand (Caveat) + section subtitle (VT323)
//   - native min/maximize/close window controls
//   - whole bar acts as a drag region for the frameless window
//
// Caller sets `subtitle` and binds `window` to the QQuickWindow/ApplicationWindow
// that should react to the control buttons.

import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Window 2.15

import BerserkMC.Ui 1.0

Rectangle {
    id: bar
    property string subtitle: "MC"
    property Window window: Window.window

    implicitHeight: 36
    color: Theme.titlebar

    // bottom border
    Rectangle {
        anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
        height: 1
        color: Theme.titlebarBorder
    }

    // Drag region — anything in the bar that isn't a control button starts a
    // system window drag (Qt 5.15 startSystemMove). We only trigger after a
    // small movement threshold so a no-move press still allows double-click to
    // toggle maximize, and we never hand-move the window (no coordinate leak).
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        property point pressPoint
        property bool   didDrag: false
        onPressed: { pressPoint = Qt.point(mouseX, mouseY); didDrag = false }
        onPositionChanged: {
            if (!pressed || didDrag || !bar.window) return;
            var dx = mouseX - pressPoint.x
            var dy = mouseY - pressPoint.y
            if (Math.abs(dx) > 4 || Math.abs(dy) > 4) {
                didDrag = true
                bar.window.startSystemMove()
            }
        }
        onDoubleClicked: bar.toggleMaximized()
    }

    function toggleMaximized() {
        if (!window) return;
        window.visibility = (window.visibility === Window.Maximized)
            ? Window.Windowed
            : Window.Maximized
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 14
        anchors.rightMargin: 6
        spacing: 10

        // Brand
        Text {
            text: "βerserk"
            color: "white"
            font.family: Theme.fontBrand
            font.pointSize: 16
            font.weight: Font.Bold
        }
        Text {
            text: "MC" + (bar.subtitle && bar.subtitle !== "MC" ? " · " + bar.subtitle : "")
            color: "#555"
            font.family: Theme.fontMono
            font.pointSize: 9
            font.letterSpacing: 3
        }

        Item { Layout.fillWidth: true }

        // Window controls
        Row {
            spacing: 2
            Repeater {
                model: [
                    { label: "—", action: "minimize", danger: false },
                    { label: "▢", action: "max",      danger: false },
                    { label: "×", action: "close",    danger: true  }
                ]
                delegate: Rectangle {
                    width: 24
                    height: 24
                    radius: 4
                    color: ctrlMouse.containsMouse
                        ? (modelData.danger ? Theme.accentRed : "#1d1d1f")
                        : "transparent"
                    Behavior on color { ColorAnimation { duration: Theme.durFast } }

                    Text {
                        anchors.centerIn: parent
                        text: modelData.label
                        color: ctrlMouse.containsMouse && modelData.danger
                            ? "white"
                            : "#6c6c70"
                        font.pointSize: 9
                    }
                    MouseArea {
                        id: ctrlMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (!bar.window) return;
                            if (modelData.action === "minimize")
                                bar.window.visibility = Window.Minimized
                            else if (modelData.action === "max")
                                bar.toggleMaximized()
                            else if (modelData.action === "close")
                                bar.window.close()
                        }
                    }
                }
            }
        }
    }
}
