// SPDX-License-Identifier: Apache-2.0
// Stack of transient toasts pinned to the bottom-right. Listens for the
// bridge's `notification(kind, message)` signal — `kind` is one of "ok",
// "error", "info" and decides the accent color.

import QtQuick 2.15
import QtQuick.Layouts 1.15

import BerserkMC.Ui 1.0

Item {
    id: root
    anchors.fill: parent
    z: 9999

    property int autoDismissMs: 4000

    ListModel { id: toasts }

    function push(kind, message) {
        toasts.append({ kind: kind || "info", message: message || "" })
    }

    // Wire into App.notification when the bridge is around.
    Connections {
        target: typeof App !== "undefined" ? App : null
        function onNotification(kind, message) { root.push(kind, message) }
    }

    Column {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: 20
        anchors.bottomMargin: 20
        spacing: 8

        Repeater {
            model: toasts

            delegate: Rectangle {
                id: card
                implicitWidth: Math.min(420, msgText.implicitWidth + 60)
                implicitHeight: msgText.implicitHeight + 26
                radius: Theme.radiusMd

                color: {
                    if (model.kind === "ok")    return Qt.rgba(0.21, 0.75, 0.33, 0.16)
                    if (model.kind === "error") return Qt.rgba(1, 0.36, 0.36, 0.16)
                    return Theme.bgElevated
                }
                border.color: {
                    if (model.kind === "ok")    return Qt.rgba(0.21, 0.75, 0.33, 0.42)
                    if (model.kind === "error") return Qt.rgba(1, 0.36, 0.36, 0.42)
                    return Theme.borderSubtle
                }
                border.width: 1

                // Slide-in from the right on mount.
                x: 40
                opacity: 0
                Behavior on x       { NumberAnimation { duration: Theme.durMd; easing.type: Easing.OutCubic } }
                Behavior on opacity { NumberAnimation { duration: Theme.durMd; easing.type: Easing.OutCubic } }
                Component.onCompleted: { card.x = 0; card.opacity = 1 }

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 8; height: 8; radius: 4
                        color: {
                            if (model.kind === "ok")    return Qt.rgba(0.21, 0.75, 0.33, 1)
                            if (model.kind === "error") return Qt.rgba(1, 0.36, 0.36, 1)
                            return Theme.textMuted
                        }
                    }

                    Text {
                        id: msgText
                        anchors.verticalCenter: parent.verticalCenter
                        text: model.message
                        color: Theme.textPrimary
                        font.family: Theme.fontBody
                        font.pointSize: 10
                        wrapMode: Text.WordWrap
                    }
                }

                Timer {
                    interval: root.autoDismissMs
                    running: true
                    repeat: false
                    onTriggered: {
                        // fade then remove
                        dismiss.start()
                    }
                }
                NumberAnimation {
                    id: dismiss
                    target: card
                    property: "opacity"
                    to: 0
                    duration: Theme.durFast
                    onStopped: toasts.remove(index)
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: dismiss.start()
                }
            }
        }
    }
}
