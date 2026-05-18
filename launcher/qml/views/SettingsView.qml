// SPDX-License-Identifier: Apache-2.0
// Unified settings view — flat layout, no fancy QML components. Sections share
// the same two-column pattern (label/desc on the left, control on the right).

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

import BerserkMC.Ui 1.0
import "../components"

Rectangle {
    id: page
    color: Theme.bgBase

    readonly property string viewTitle: "RÉGLAGES"
    signal back()

    // ===== Bridge-backed settings =====
    property string javaPath: ""
    property real   maxRam:   1024
    property bool   detectJava: true
    property bool   animations: true
    property bool   closeOnLaunch: false
    property bool   showConsoleOnStart: false
    property int    accentIndex: 0
    readonly property var accents: [
        { name: "Vert Berserk", hex: "#36c054" },
        { name: "Bleu",         hex: "#3399ff" },
        { name: "Violet",       hex: "#a755e8" },
        { name: "Rouge",        hex: "#e35858" },
        { name: "Orange",       hex: "#f6a623" }
    ]

    // Load persisted values once, before any onChanged handler can fire.
    property bool _ready: false
    Component.onCompleted: {
        if (typeof App !== "undefined") {
            page.javaPath           = App.getSetting("JavaPath", "")
            page.maxRam             = parseInt(App.getSetting("MaxMemAlloc", 1024))
            page.closeOnLaunch      = App.getSetting("AutoCloseConsole", false) === true
                                   || App.getSetting("AutoCloseConsole", false) === "true"
            page.showConsoleOnStart = App.getSetting("ShowConsole", false) === true
                                   || App.getSetting("ShowConsole", false) === "true"
            // Restore accent
            var savedAccent = App.getSetting("AccentHex", "")
            if (savedAccent && savedAccent.length) {
                for (var i = 0; i < page.accents.length; ++i) {
                    if (page.accents[i].hex === savedAccent) { page.accentIndex = i; break }
                }
                Theme.setAccent(savedAccent)
            }
        }
        page._ready = true
    }

    // Persist on every change (debounced just by event coalescing).
    onJavaPathChanged:            if (_ready && typeof App !== "undefined") App.setSetting("JavaPath", javaPath)
    onMaxRamChanged:              if (_ready && typeof App !== "undefined") App.setSetting("MaxMemAlloc", Math.round(maxRam))
    onCloseOnLaunchChanged:       if (_ready && typeof App !== "undefined") App.setSetting("AutoCloseConsole", closeOnLaunch)
    onShowConsoleOnStartChanged:  if (_ready && typeof App !== "undefined") App.setSetting("ShowConsole", showConsoleOnStart)
    onAccentIndexChanged: {
        if (!_ready) return
        var hex = accents[accentIndex].hex
        Theme.setAccent(hex)
        if (typeof App !== "undefined") App.setSetting("AccentHex", hex)
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        PageHeader {
            Layout.fillWidth: true
            iconName: "gear"
            title: qsTr("Réglages")
            subtitle: qsTr("Java, apparence, comportement")
            onBack: page.back()
        }

        // ===== Scrollable body =====
        ScrollView {
            id: scroll
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            ColumnLayout {
                width: scroll.availableWidth
                spacing: 28

                Item { implicitHeight: 4 }

                // ----- JAVA -----
                ColumnLayout {
                    Layout.leftMargin: 36
                    Layout.rightMargin: 36
                    Layout.fillWidth: true
                    spacing: 14

                    // Section header
                    Column {
                        Layout.fillWidth: true
                        spacing: 4
                        Row {
                            spacing: 10
                            Rectangle { width: 8; height: 8; radius: 4; color: Theme.accentStrong; anchors.verticalCenter: parent.verticalCenter }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: qsTr("JAVA")
                                color: Theme.textPrimary
                                font.family: Theme.fontBody
                                font.pointSize: 12
                                font.letterSpacing: 1.2
                                font.weight: Font.Bold
                            }
                        }
                        Text {
                            text: qsTr("Configure le runtime utilisé pour lancer Minecraft.")
                            color: Theme.textDim
                            font.family: Theme.fontBody
                            font.pointSize: 10
                        }
                    }

                    // Row: JDK path
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 16
                        Column {
                            Layout.fillWidth: true
                            spacing: 2
                            Text { text: qsTr("Chemin du JDK"); color: Theme.textPrimary; font.family: Theme.fontBody; font.pointSize: 11; font.weight: Font.DemiBold }
                            Text { text: qsTr("javaw.exe à utiliser pour lancer le jeu"); color: Theme.textDim; font.family: Theme.fontBody; font.pointSize: 10 }
                        }
                        Row {
                            spacing: 6
                            Rectangle {
                                width: 340; height: 36
                                radius: Theme.radiusMd
                                color: Theme.bgInput
                                border.color: Theme.borderSubtle
                                border.width: 1
                                TextField {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 12
                                    text: page.javaPath
                                    color: Theme.textPrimary
                                    font.family: Theme.fontMono
                                    font.pointSize: 9
                                    background: null
                                    verticalAlignment: TextInput.AlignVCenter
                                    onTextChanged: page.javaPath = text
                                }
                            }
                            IconButton {
                                variant: "filled"
                                iconName: "folder"
                                dense: true
                                onClicked: {
                                    if (typeof App === "undefined") return
                                    var p = App.browseForJava()
                                    if (p && p.length) page.javaPath = p
                                }
                            }
                        }
                    }

                    // Row: RAM slider
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 16
                        Column {
                            Layout.fillWidth: true
                            spacing: 2
                            Text { text: qsTr("RAM maximale"); color: Theme.textPrimary; font.family: Theme.fontBody; font.pointSize: 11; font.weight: Font.DemiBold }
                            Text { text: qsTr("Mémoire allouée à Minecraft"); color: Theme.textDim; font.family: Theme.fontBody; font.pointSize: 10 }
                        }
                        Row {
                            spacing: 12
                            Slider {
                                from: 512
                                to: 16384
                                stepSize: 256
                                value: page.maxRam
                                onMoved: page.maxRam = value
                                implicitWidth: 220
                                background: Rectangle {
                                    x: parent.leftPadding
                                    y: parent.topPadding + parent.availableHeight/2 - 2
                                    width: parent.availableWidth
                                    height: 4
                                    radius: 2
                                    color: Theme.bgInput
                                    Rectangle {
                                        width: parent.parent.visualPosition * parent.width
                                        height: parent.height
                                        radius: 2
                                        color: Theme.accentStrong
                                    }
                                }
                                handle: Rectangle {
                                    x: parent.leftPadding + parent.visualPosition * (parent.availableWidth - width)
                                    y: parent.topPadding + parent.availableHeight/2 - height/2
                                    width: 16; height: 16
                                    radius: 8
                                    color: Theme.accentStrong
                                    border.color: Theme.bgBase
                                    border.width: 2
                                }
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: page.maxRam + " Mo"
                                color: Theme.textMuted
                                font.family: Theme.fontMono
                                font.pointSize: 10
                                width: 70
                                horizontalAlignment: Text.AlignRight
                            }
                        }
                    }

                    // Row: detect java toggle
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 16
                        Column {
                            Layout.fillWidth: true
                            spacing: 2
                            Text { text: qsTr("Détecter automatiquement les Java installés"); color: Theme.textPrimary; font.family: Theme.fontBody; font.pointSize: 11; font.weight: Font.DemiBold }
                            Text { text: qsTr("Scan Adoptium / Oracle / Azul sur le système"); color: Theme.textDim; font.family: Theme.fontBody; font.pointSize: 10 }
                        }
                        Rectangle {
                            implicitWidth: 40; implicitHeight: 22
                            radius: 11
                            color: page.detectJava ? Theme.accent : Theme.bgInput
                            Behavior on color { ColorAnimation { duration: Theme.durFast } }
                            Rectangle {
                                x: page.detectJava ? parent.width - width - 3 : 3
                                y: 3
                                width: 16; height: 16
                                radius: 8
                                color: page.detectJava ? "white" : Theme.textMuted
                                Behavior on x     { NumberAnimation { duration: Theme.durFast; easing.type: Easing.OutCubic } }
                                Behavior on color { ColorAnimation { duration: Theme.durFast } }
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    page.detectJava = !page.detectJava
                                    if (page.detectJava && typeof App !== "undefined")
                                        App.detectJava()
                                }
                            }
                        }
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: Theme.borderSubtle; Layout.topMargin: 12 }
                }

                // ----- APPARENCE -----
                ColumnLayout {
                    Layout.leftMargin: 36
                    Layout.rightMargin: 36
                    Layout.fillWidth: true
                    spacing: 14

                    Column {
                        Layout.fillWidth: true
                        spacing: 4
                        Row {
                            spacing: 10
                            Rectangle { width: 8; height: 8; radius: 4; color: Theme.accentStrong; anchors.verticalCenter: parent.verticalCenter }
                            Text { anchors.verticalCenter: parent.verticalCenter; text: qsTr("APPARENCE"); color: Theme.textPrimary; font.family: Theme.fontBody; font.pointSize: 12; font.letterSpacing: 1.2; font.weight: Font.Bold }
                        }
                        Text { text: qsTr("Thème global et accent."); color: Theme.textDim; font.family: Theme.fontBody; font.pointSize: 10 }
                    }

                    // Accent swatches
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 16
                        Column {
                            Layout.fillWidth: true
                            spacing: 2
                            Text { text: qsTr("Couleur d'accent"); color: Theme.textPrimary; font.family: Theme.fontBody; font.pointSize: 11; font.weight: Font.DemiBold }
                            Text { text: qsTr("Boutons, focus, sélections"); color: Theme.textDim; font.family: Theme.fontBody; font.pointSize: 10 }
                        }
                        Row {
                            spacing: 8
                            Repeater {
                                model: page.accents
                                delegate: Rectangle {
                                    implicitWidth: 28; implicitHeight: 28
                                    radius: 14
                                    color: modelData.hex
                                    border.color: page.accentIndex === index ? Theme.textPrimary : "transparent"
                                    border.width: 2
                                    scale: swatchHover.containsMouse ? 1.12 : 1.0
                                    Behavior on scale { NumberAnimation { duration: Theme.durFast; easing.type: Easing.OutCubic } }
                                    MouseArea {
                                        id: swatchHover
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: page.accentIndex = index
                                        ToolTip.text: modelData.name
                                        ToolTip.visible: containsMouse
                                        ToolTip.delay: 400
                                    }
                                }
                            }
                        }
                    }

                    // Animations toggle
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 16
                        Column {
                            Layout.fillWidth: true
                            spacing: 2
                            Text { text: qsTr("Animations"); color: Theme.textPrimary; font.family: Theme.fontBody; font.pointSize: 11; font.weight: Font.DemiBold }
                            Text { text: qsTr("Désactiver pour des machines plus lentes"); color: Theme.textDim; font.family: Theme.fontBody; font.pointSize: 10 }
                        }
                        Rectangle {
                            implicitWidth: 40; implicitHeight: 22
                            radius: 11
                            color: page.animations ? Theme.accent : Theme.bgInput
                            Behavior on color { ColorAnimation { duration: Theme.durFast } }
                            Rectangle {
                                x: page.animations ? parent.width - width - 3 : 3
                                y: 3
                                width: 16; height: 16
                                radius: 8
                                color: page.animations ? "white" : Theme.textMuted
                                Behavior on x { NumberAnimation { duration: Theme.durFast; easing.type: Easing.OutCubic } }
                            }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: page.animations = !page.animations }
                        }
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: Theme.borderSubtle; Layout.topMargin: 12 }
                }

                // ----- COMPORTEMENT -----
                ColumnLayout {
                    Layout.leftMargin: 36
                    Layout.rightMargin: 36
                    Layout.fillWidth: true
                    spacing: 14

                    Column {
                        Layout.fillWidth: true
                        spacing: 4
                        Row {
                            spacing: 10
                            Rectangle { width: 8; height: 8; radius: 4; color: Theme.accentStrong; anchors.verticalCenter: parent.verticalCenter }
                            Text { anchors.verticalCenter: parent.verticalCenter; text: qsTr("COMPORTEMENT"); color: Theme.textPrimary; font.family: Theme.fontBody; font.pointSize: 12; font.letterSpacing: 1.2; font.weight: Font.Bold }
                        }
                        Text { text: qsTr("Lancement et fenêtre du jeu."); color: Theme.textDim; font.family: Theme.fontBody; font.pointSize: 10 }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 16
                        Column {
                            Layout.fillWidth: true
                            spacing: 2
                            Text { text: qsTr("Fermer le launcher au lancement de Minecraft"); color: Theme.textPrimary; font.family: Theme.fontBody; font.pointSize: 11; font.weight: Font.DemiBold }
                            Text { text: qsTr("Économise la RAM pendant que tu joues"); color: Theme.textDim; font.family: Theme.fontBody; font.pointSize: 10 }
                        }
                        Rectangle {
                            implicitWidth: 40; implicitHeight: 22
                            radius: 11
                            color: page.closeOnLaunch ? Theme.accent : Theme.bgInput
                            Behavior on color { ColorAnimation { duration: Theme.durFast } }
                            Rectangle {
                                x: page.closeOnLaunch ? parent.width - width - 3 : 3
                                y: 3
                                width: 16; height: 16
                                radius: 8
                                color: page.closeOnLaunch ? "white" : Theme.textMuted
                                Behavior on x { NumberAnimation { duration: Theme.durFast; easing.type: Easing.OutCubic } }
                            }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: page.closeOnLaunch = !page.closeOnLaunch }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 16
                        Column {
                            Layout.fillWidth: true
                            spacing: 2
                            Text { text: qsTr("Afficher la console au démarrage"); color: Theme.textPrimary; font.family: Theme.fontBody; font.pointSize: 11; font.weight: Font.DemiBold }
                            Text { text: qsTr("Pour debug les crashes"); color: Theme.textDim; font.family: Theme.fontBody; font.pointSize: 10 }
                        }
                        Rectangle {
                            implicitWidth: 40; implicitHeight: 22
                            radius: 11
                            color: page.showConsoleOnStart ? Theme.accent : Theme.bgInput
                            Behavior on color { ColorAnimation { duration: Theme.durFast } }
                            Rectangle {
                                x: page.showConsoleOnStart ? parent.width - width - 3 : 3
                                y: 3
                                width: 16; height: 16
                                radius: 8
                                color: page.showConsoleOnStart ? "white" : Theme.textMuted
                                Behavior on x { NumberAnimation { duration: Theme.durFast; easing.type: Easing.OutCubic } }
                            }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: page.showConsoleOnStart = !page.showConsoleOnStart }
                        }
                    }

                    // Window size selector
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 16
                        Column {
                            Layout.fillWidth: true
                            spacing: 2
                            Text { text: qsTr("Taille de la fenêtre Minecraft"); color: Theme.textPrimary; font.family: Theme.fontBody; font.pointSize: 11; font.weight: Font.DemiBold }
                            Text { text: qsTr("Définit la résolution de départ du jeu"); color: Theme.textDim; font.family: Theme.fontBody; font.pointSize: 10 }
                        }
                        ComboBox {
                            id: sizeCombo
                            implicitWidth: 180
                            model: [
                                qsTr("854 × 480"),
                                qsTr("1280 × 720"),
                                qsTr("1920 × 1080"),
                                qsTr("Plein écran")
                            ]
                            property var presets: [
                                { w: 854,  h: 480,  max: false },
                                { w: 1280, h: 720,  max: false },
                                { w: 1920, h: 1080, max: false },
                                { w: 0,    h: 0,    max: true  }
                            ]
                            background: Rectangle {
                                implicitHeight: 36
                                radius: Theme.radiusMd
                                color: sizeCombo.activeFocus ? Theme.bgInputOff : Theme.bgInput
                                border.color: sizeCombo.activeFocus ? Theme.accentRing : Theme.borderSubtle
                                border.width: 1
                            }
                            contentItem: Text {
                                leftPadding: 12
                                text: sizeCombo.displayText
                                color: Theme.textPrimary
                                font.family: Theme.fontBody
                                font.pointSize: 11
                                verticalAlignment: Text.AlignVCenter
                            }
                            onActivated: {
                                if (!page._ready || typeof App === "undefined") return
                                var p = presets[index]
                                App.setSetting("LaunchMaximized", p.max)
                                if (!p.max) {
                                    App.setSetting("MinecraftWinWidth",  p.w)
                                    App.setSetting("MinecraftWinHeight", p.h)
                                }
                            }
                            Component.onCompleted: {
                                if (typeof App === "undefined") return
                                var isMax = App.getSetting("LaunchMaximized", false) === true
                                if (isMax) { sizeCombo.currentIndex = 3; return }
                                var w = parseInt(App.getSetting("MinecraftWinWidth", 854))
                                for (var i = 0; i < 3; ++i) {
                                    if (presets[i].w === w) { sizeCombo.currentIndex = i; return }
                                }
                                sizeCombo.currentIndex = 0
                            }
                        }
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: Theme.borderSubtle; Layout.topMargin: 12 }
                }

                // ----- À PROPOS -----
                ColumnLayout {
                    Layout.leftMargin: 36
                    Layout.rightMargin: 36
                    Layout.fillWidth: true
                    spacing: 14

                    Column {
                        Layout.fillWidth: true
                        spacing: 4
                        Row {
                            spacing: 10
                            Rectangle { width: 8; height: 8; radius: 4; color: Theme.accentStrong; anchors.verticalCenter: parent.verticalCenter }
                            Text { anchors.verticalCenter: parent.verticalCenter; text: qsTr("À PROPOS"); color: Theme.textPrimary; font.family: Theme.fontBody; font.pointSize: 12; font.letterSpacing: 1.2; font.weight: Font.Bold }
                        }
                        Text { text: qsTr("Infos build."); color: Theme.textDim; font.family: Theme.fontBody; font.pointSize: 10 }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 16
                        Column {
                            Layout.fillWidth: true
                            spacing: 2
                            Text { text: qsTr("Version"); color: Theme.textPrimary; font.family: Theme.fontBody; font.pointSize: 11; font.weight: Font.DemiBold }
                            Text { text: qsTr("BerserkMC 0.1.0 — fork de MultiMC 5"); color: Theme.textDim; font.family: Theme.fontBody; font.pointSize: 10 }
                        }
                        IconButton {
                            variant: "filled"
                            text: qsTr("Voir le changelog")
                            onClicked: if (typeof App !== "undefined") App.openChangelog()
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 16
                        Column {
                            Layout.fillWidth: true
                            spacing: 2
                            Text { text: qsTr("Dossier launcher"); color: Theme.textPrimary; font.family: Theme.fontBody; font.pointSize: 11; font.weight: Font.DemiBold }
                            Text { text: qsTr("C:\\Users\\Karim\\Documents\\BerserkLauncher"); color: Theme.textDim; font.family: Theme.fontBody; font.pointSize: 10 }
                        }
                        IconButton {
                            variant: "filled"
                            iconName: "folder"
                            text: qsTr("Ouvrir")
                            onClicked: if (typeof App !== "undefined") App.openFolder("launcher")
                        }
                    }
                }

                Item { Layout.fillHeight: true; implicitHeight: 32 }
            }
        }
    }
}
