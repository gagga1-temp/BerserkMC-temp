// SPDX-License-Identifier: Apache-2.0
// First-launch welcome screen. Offline account creation is the primary path;
// Microsoft login is a discrete opt-in pinned bottom-right.

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtGraphicalEffects 1.15

import BerserkMC.Ui 1.0
import "../components"

Rectangle {
    id: page
    color: Theme.bgBase

    signal offlineAccountCreated(string playerName)
    signal microsoftLoginRequested()

    // Soft accent gradient backdrop (vertical band centered on the logo area)
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0.0;  color: Qt.rgba(0,0,0,0) }
            GradientStop { position: 0.40; color: Theme.accentGlow2 }
            GradientStop { position: 1.0;  color: Qt.rgba(0,0,0,0) }
        }
    }

    // Wider glow centered roughly behind the logo via QtGraphicalEffects.
    Item {
        id: glowAnchor
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -80
        width: 0; height: 0
        Rectangle {
            anchors.centerIn: parent
            width: 320; height: 320
            radius: 160
            color: Theme.accent
            opacity: 0.12
        }
        layer.enabled: true
        layer.effect: FastBlur {
            radius: 96
            transparentBorder: true
        }
    }

    // Centered content stack
    ColumnLayout {
        anchors.centerIn: parent
        width: 420
        spacing: 12

        Image {
            id: logo
            Layout.alignment: Qt.AlignHCenter
            source: "qrc:/logo.png"
            sourceSize.width: 192
            sourceSize.height: 192
            width: 96
            height: 96
            fillMode: Image.PreserveAspectFit
            smooth: true

            // Subtle fade-up entrance
            opacity: 0
            transform: Translate { id: logoTrans; y: 12 }
            Component.onCompleted: logoAnim.start()
            ParallelAnimation {
                id: logoAnim
                NumberAnimation { target: logo; property: "opacity"; to: 1.0; duration: Theme.durSlow; easing.type: Easing.OutCubic }
                NumberAnimation { target: logoTrans; property: "y"; to: 0; duration: Theme.durSlow; easing.type: Easing.OutCubic }
            }
        }

        Text {
            id: title
            Layout.alignment: Qt.AlignHCenter
            text: qsTr("Bienvenue dans BerserkMC")
            color: Theme.textPrimary
            font.family: Theme.fontBody
            font.pointSize: 22
            font.weight: Font.Bold
            opacity: 0
            transform: Translate { id: titleTrans; y: 12 }
            Component.onCompleted: titleAnim.start()
            ParallelAnimation {
                id: titleAnim
                NumberAnimation { target: title; property: "opacity"; to: 1.0; duration: Theme.durSlow; easing.type: Easing.OutCubic }
                NumberAnimation { target: titleTrans; property: "y"; to: 0; duration: Theme.durSlow; easing.type: Easing.OutCubic }
                PauseAnimation { duration: 80 }
            }
        }

        Text {
            id: subtitle
            Layout.alignment: Qt.AlignHCenter
            Layout.fillWidth: true
            text: qsTr("Crée un compte hors-ligne pour commencer. Tu pourras lancer Minecraft sans Microsoft et rejoindre les serveurs qui acceptent les comptes locaux.")
            color: Theme.textMuted
            font.family: Theme.fontBody
            font.pointSize: 11
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
            opacity: 0
            Component.onCompleted: subAnim.start()
            NumberAnimation { id: subAnim; target: subtitle; property: "opacity"; to: 1.0; duration: Theme.durSlow; easing.type: Easing.OutCubic }
        }

        Item { height: 12; Layout.fillWidth: true }

        Text {
            text: qsTr("PSEUDO EN JEU")
            color: Theme.textDim
            font.family: Theme.fontBody
            font.pointSize: 9
            font.letterSpacing: 1
            font.weight: Font.DemiBold
        }

        Rectangle {
            id: nameField
            Layout.fillWidth: true
            implicitHeight: 48
            radius: Theme.radiusMd
            color: Theme.bgInput
            border.color: nameInput.activeFocus ? Theme.accentRing : Theme.borderSubtle
            border.width: 1
            Behavior on border.color { ColorAnimation { duration: Theme.durFast } }

            TextField {
                id: nameInput
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                placeholderText: qsTr("Karim_")
                placeholderTextColor: Theme.textDim
                color: Theme.textPrimary
                font.family: Theme.fontBody
                font.pointSize: 14
                maximumLength: 16
                background: null
                verticalAlignment: TextInput.AlignVCenter
                validator: RegExpValidator { regExp: /^[a-zA-Z0-9_]{0,16}$/ }
                onAccepted: createBtn.tryCreate()
                focus: true
            }
        }

        Text {
            Layout.fillWidth: true
            text: nameInput.text.length === 0
                ? qsTr("3 à 16 caractères — lettres, chiffres ou underscore")
                : (nameInput.text.length < 3
                    ? qsTr("Encore %1 caractère(s)…").arg(3 - nameInput.text.length)
                    : qsTr("✓ Nom valide"))
            color: nameInput.text.length >= 3 ? Theme.accentStrong : Theme.textDim
            font.family: Theme.fontBody
            font.pointSize: 10
            Behavior on color { ColorAnimation { duration: Theme.durFast } }
        }

        Item { height: 6; Layout.fillWidth: true }

        Rectangle {
            id: createBtn
            Layout.fillWidth: true
            implicitHeight: 48
            radius: Theme.radiusMd
            enabled: nameInput.text.length >= 3
            opacity: enabled ? 1.0 : 0.5
            color: enabled && createHover.containsMouse ? Theme.accent : Theme.accentSoft
            border.color: Theme.accentRing
            border.width: 1
            Behavior on color   { ColorAnimation { duration: Theme.durFast } }
            Behavior on opacity { NumberAnimation { duration: Theme.durFast } }
            scale: createHover.pressed && enabled ? 0.98 : 1.0
            Behavior on scale   { NumberAnimation { duration: Theme.durFast; easing.type: Easing.OutCubic } }

            function tryCreate() {
                if (nameInput.text.length >= 3) {
                    page.offlineAccountCreated(nameInput.text)
                }
            }

            Row {
                anchors.centerIn: parent
                spacing: 8
                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "user"
                    color: createHover.containsMouse && createBtn.enabled ? "white" : Theme.accentStrong
                    size: 18
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("Créer mon compte hors-ligne")
                    color: createHover.containsMouse && createBtn.enabled ? "white" : Theme.accentStrong
                    font.family: Theme.fontBody
                    font.pointSize: 12
                    font.weight: Font.Bold
                    Behavior on color { ColorAnimation { duration: Theme.durFast } }
                }
            }

            MouseArea {
                id: createHover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: createBtn.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: createBtn.tryCreate()
            }
        }
    }

    // Microsoft account opt-in — discrete, bottom right
    Row {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: 24
        anchors.bottomMargin: 24
        spacing: 0

        Rectangle {
            id: msBtn
            implicitWidth: msRow.implicitWidth + 28
            implicitHeight: 38
            radius: Theme.radiusMd
            color: msHover.containsMouse ? Theme.bgElevated : "transparent"
            border.color: msHover.containsMouse ? Theme.borderSubtle : "transparent"
            border.width: 1
            Behavior on color        { ColorAnimation { duration: Theme.durFast } }
            Behavior on border.color { ColorAnimation { duration: Theme.durFast } }

            Row {
                id: msRow
                anchors.centerIn: parent
                spacing: 8

                // Tiny Microsoft 4-square mark
                Item {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 14; height: 14
                    Rectangle { width: 6; height: 6; color: "#f25022" }
                    Rectangle { x: 8; width: 6; height: 6; color: "#7fba00" }
                    Rectangle { y: 8; width: 6; height: 6; color: "#00a4ef" }
                    Rectangle { x: 8; y: 8; width: 6; height: 6; color: "#ffb900" }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("J'ai un compte Microsoft")
                    color: Theme.textMuted
                    font.family: Theme.fontBody
                    font.pointSize: 10
                }
            }

            MouseArea {
                id: msHover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: page.microsoftLoginRequested()
            }
        }
    }
}
