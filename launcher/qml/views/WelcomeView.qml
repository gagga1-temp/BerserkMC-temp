// SPDX-License-Identifier: Apache-2.0
// First-launch welcome screen. Offline account creation is the only path here;
// Microsoft accounts are added later from the Comptes page.

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtGraphicalEffects 1.15

import BerserkMC.Ui 1.0
import "../components"

Rectangle {
    id: page
    color: Theme.bgBase

    readonly property string viewTitle: "BIENVENUE"

    signal offlineAccountCreated(string playerName, string skinKey, string skinVariant, string language, int maxRam)

    property int step: 0 // 0: language, 1: pseudo+skin, 2: RAM
    property string selectedLang: ""
    property bool isRtl: selectedLang.indexOf("ar") === 0 || selectedLang.indexOf("he") === 0 || selectedLang.indexOf("fa") === 0 || selectedLang.indexOf("ur") === 0
    property int _langTick: 0

    function tr(s) { var _ = _langTick; return qsTr(s) }

    property int maxRam: 4096


    Component.onCompleted: {
        if (typeof App !== "undefined") {
            var currentLang = App.getSetting("Language", "")
            if (currentLang && currentLang.length) {
                selectedLang = currentLang
            } else {
                selectedLang = "en_US"
            }
            var storedRam = App.getSetting("MaxMemAlloc", 1024)
            maxRam = (storedRam <= 1024) ? 4096 : storedRam
            if (maxRam < 512) maxRam = 4096
            // ensure selectedLang exists in the available list
            var langs = App.availableLanguages
            var found = false
            for (var i = 0; i < langs.length; i++) {
                if (langs[i].key === selectedLang) { found = true; break }
            }
            if (!found && langs.length > 0) selectedLang = langs[0].key
        }
    }

    Connections {
        target: (typeof App !== "undefined") ? App : null
        function onLanguageApplied() { page._langTick = page._langTick + 1 }
    }



    function nextStep() {
        if (step < 2) step = step + 1
    }

    function prevStep() {
        if (step > 0) step = step - 1
    }

    // Background
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0.0; color: Qt.rgba(0,0,0,0) }
            GradientStop { position: 0.40; color: Theme.accentGlow2 }
            GradientStop { position: 1.0; color: Qt.rgba(0,0,0,0) }
        }
    }

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
        layer.effect: FastBlur { radius: 96; transparentBorder: true }
    }

    ColumnLayout {
        anchors.centerIn: parent
        width: 460
        spacing: 14
        LayoutMirroring.enabled: page.isRtl
        LayoutMirroring.childrenInherit: true

        Item {
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: 96
            implicitHeight: 96
            Image {
                id: logoBlur
                anchors.fill: parent
                source: "qrc:/logo.png"
                sourceSize.width: 192; sourceSize.height: 192
                fillMode: Image.PreserveAspectFit
                opacity: 0.35
                scale: 1.18
                smooth: true
                layer.enabled: true
                layer.effect: FastBlur { radius: 32 }
            }
            Image {
                id: logo
                anchors.fill: parent
                source: "qrc:/logo.png"
                sourceSize.width: 192; sourceSize.height: 192
                fillMode: Image.PreserveAspectFit
                smooth: true
            }
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: page.tr("Configuration rapide")
            color: Theme.textPrimary
            font.family: Theme.fontBody
            font.pointSize: 22
            font.weight: Font.Bold
            font.letterSpacing: -0.3
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            color: Theme.textMuted
            font.family: Theme.fontBody
            font.pointSize: 10
            text: step === 0 ? page.tr("Étape 1/3 — Langue") : (step === 1 ? page.tr("Étape 2/3 — Pseudo & Skin") : page.tr("Étape 3/3 — Allocation RAM"))
        }

        Item { height: 6 }

        // Step 0: Language
        ColumnLayout {
            visible: step === 0
            Layout.fillWidth: true
            spacing: 10
            Text {
                text: page.tr("CHOISIS TA LANGUE")
                color: Theme.textDim
                font.family: Theme.fontBody
                font.pointSize: 9
                font.letterSpacing: 1
                font.weight: Font.DemiBold
            }
            ListView {
                id: langList
                Layout.fillWidth: true
                implicitHeight: 180
                model: (typeof App !== "undefined") ? App.availableLanguages : []
                spacing: 4
                clip: true
                flickDeceleration: 8000
                maximumFlickVelocity: 1500
                boundsBehavior: Flickable.StopAtBounds
                delegate: Rectangle {
                    width: langList.width
                    height: 36
                    radius: Theme.radiusMd
                    color: page.selectedLang === modelData.key ? Theme.accentSoft : (langHover.containsMouse ? Theme.bgElevated : Theme.bgInput)
                    border.color: page.selectedLang === modelData.key ? "#3fb950" : Theme.borderSubtle
                    border.width: page.selectedLang === modelData.key ? 2 : 1
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 8
                        Text {
                            Layout.fillWidth: true
                            text: modelData.label
                            color: Theme.textPrimary
                            font.family: Theme.fontBody
                            font.pointSize: 11
                            font.weight: page.selectedLang === modelData.key ? Font.DemiBold : Font.Normal
                        }
                        Text {
                            visible: page.selectedLang === modelData.key
                            text: "✓"
                            color: "#3fb950"
                            font.family: Theme.fontBody
                            font.pointSize: 12
                            font.weight: Font.Bold
                        }
                    }
                    MouseArea {
                        id: langHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            page.selectedLang = modelData.key
                            if (typeof App !== "undefined") App.setLanguage(modelData.key)
                            page._langTick = page._langTick + 1
                        }
                    }
                }
            }
            Item { height: 4 }
            Row {
                Layout.alignment: Qt.AlignRight
                spacing: 8
                IconButton {
                    variant: "primary"
                    text: page.tr("Suivant")
                    onClicked: nextStep()
                }
            }
        }

        // Step 1: Pseudo + Skin
        ColumnLayout {
            visible: step === 1
            Layout.fillWidth: true
            spacing: 10
            Text {
                text: page.tr("PSEUDO EN JEU")
                color: Theme.textDim
                font.family: Theme.fontBody
                font.pointSize: 9
                font.letterSpacing: 1
                font.weight: Font.DemiBold
            }
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 44
                radius: Theme.radiusMd
                color: Theme.bgInput
                border.color: nameInput.activeFocus ? Theme.accentRing : Theme.borderSubtle
                border.width: 1
                TextField {
                    id: nameInput
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    placeholderText: page.tr("Pseudo")
                    placeholderTextColor: Theme.textDim
                    color: Theme.textPrimary
                    font.family: Theme.fontBody
                    font.pointSize: 12
                    maximumLength: 16
                    background: null
                    verticalAlignment: TextInput.AlignVCenter
                    validator: RegExpValidator { regExp: /^[a-zA-Z0-9_]{0,16}$/ }
                    focus: true
                }
            }
            Text {
                Layout.fillWidth: true
                text: nameInput.text.length === 0 ? page.tr("3 à 16 caractères") : (nameInput.text.length < 3 ? page.tr("Encore %1…").arg(3 - nameInput.text.length) : page.tr("✓ OK"))
                color: nameInput.text.length >= 3 ? Theme.accentStrong : Theme.textDim
                font.family: Theme.fontBody
                font.pointSize: 9
            }
            SkinPicker {
                id: createSkin
                Layout.fillWidth: true
                showNone: true
                systemOnly: true
                selectedKey: "Steve"
                selectedVariant: "classic"
            }
            Row {
                Layout.alignment: Qt.AlignRight
                spacing: 8
                IconButton { variant: "ghost"; text: page.tr("Retour"); onClicked: prevStep() }
                IconButton { variant: "primary"; text: page.tr("Suivant"); enabled: nameInput.text.length >= 3; onClicked: nextStep() }
            }
        }

        // Step 2: RAM
        ColumnLayout {
            visible: step === 2
            Layout.fillWidth: true
            spacing: 10
            Text {
                text: page.tr("ALLOCATION RAM")
                color: Theme.textDim
                font.family: Theme.fontBody
                font.pointSize: 9
                font.letterSpacing: 1
                font.weight: Font.DemiBold
            }
            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: page.maxRam + " Mo"
                    color: Theme.textPrimary
                    font.family: Theme.fontMono
                    font.pointSize: 11
                    font.weight: Font.DemiBold
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: page.tr("Recommandé : 4096 Mo")
                    color: Theme.textMuted
                    font.family: Theme.fontBody
                    font.pointSize: 9
                }
            }
            Slider {
                id: ramSlider
                Layout.fillWidth: true
                from: 512
                to: Math.max(4096, (typeof App !== "undefined" ? App.systemRamMB() : 16384))
                stepSize: 256
                value: page.maxRam
                onMoved: page.maxRam = value
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
                text: page.tr("Pour la majorité des instances, 4–6 Go suffisent. Plus n'est pas forcément mieux.")
                color: Theme.textMuted
                font.family: Theme.fontBody
                font.pointSize: 9
                wrapMode: Text.WordWrap
            }
            Row {
                Layout.alignment: Qt.AlignRight
                spacing: 8
                IconButton { variant: "ghost"; text: page.tr("Retour"); onClicked: prevStep() }
                IconButton {
                    variant: "primary"
                    text: page.tr("Terminer")
                    enabled: nameInput.text.length >= 3
                    onClicked: page.offlineAccountCreated(nameInput.text, createSkin.selectedKey, createSkin.selectedVariant, page.selectedLang, page.maxRam)
                }
            }
        }
    }
}
