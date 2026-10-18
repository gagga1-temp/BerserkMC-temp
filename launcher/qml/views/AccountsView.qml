// SPDX-License-Identifier: Apache-2.0
// Accounts view: left list of accounts, right detail panel. Two account kinds:
// local "offline" profiles (just a player name, played with auth disabled) and
// Microsoft accounts signed in through the device-code popup below.

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

import BerserkMC.Ui 1.0
import "../components"

Rectangle {
    id: page
    color: Theme.bgBase

    readonly property string viewTitle: "COMPTES"
    signal back()

    // Mirror App.accounts (QVariantList) into a ListModel for the delegates.
    ListModel { id: accounts }

    function rebuildAccountsModel() {
        accounts.clear()
        if (typeof App === "undefined") return
        var list = App.accounts
        for (var i = 0; i < list.length; ++i) {
            var src = list[i]
            var initial = (src.displayName || "?").charAt(0).toUpperCase()
            accounts.append({
                internalId: src.internalId || "",
                name:       src.displayName || "(sans nom)",
                initial:    initial,
                kind:       src.kind || "Offline",
                uuid:       src.offlineUuid || "",
                isDefault:  src.isDefault === true,
                skinKey:    src.skinKey || "",
                skinVariant:src.skinVariant || "classic",
                hasSkin:    src.hasSkin === true
            })
        }
        // There is no separate "default" concept in the UI: the selected account
        // is the active one, so keep the highlight on the active account.
        for (var j = 0; j < accounts.count; ++j) {
            if (accounts.get(j).isDefault) { page.selectedIndex = j; break }
        }
        if (page.selectedIndex >= accounts.count) page.selectedIndex = Math.max(0, accounts.count - 1)
        page.syncDetailSkin()
    }

    // Head preview URL for an account (served by the cpp "skins" provider).
    function avatarFor(internalId, hasSkin) {
        return hasSkin ? ("image://skins/account/" + internalId + "?v=" + internalId) : ""
    }

    // Keep the detail skin picker in sync with the selected account.
    function syncDetailSkin() {
        var c = current()
        detailSkin.selectedKey = c ? (c.skinKey || "") : ""
        detailSkin.selectedVariant = c ? (c.skinVariant || "classic") : "classic"
    }

    Component.onCompleted: rebuildAccountsModel()

    Connections {
        target: typeof App !== "undefined" ? App : null
        function onAccountsChanged() { page.rebuildAccountsModel() }
    }

    // ===== Microsoft sign-in state (driven by the bridge, see msLoginPopup) =====
    property bool   msRunning: false
    property string msLink: ""
    property string msCode: ""
    property string msStatus: ""
    property string msError: ""
    property int    msRemaining: 0

    Connections {
        target: typeof App !== "undefined" ? App : null
        function onMicrosoftLoginRunningChanged(running) { page.msRunning = running }
        function onMicrosoftLoginVerification(url, code, expiresIn) {
            page.msLink = url
            page.msCode = code
            page.msRemaining = expiresIn
            msExpiryTimer.restart()
        }
        function onMicrosoftLoginStatus(text) { page.msStatus = text }
        function onMicrosoftLoginProgress(current, total) { /* not shown: the countdown covers it */ }
        function onMicrosoftLoginFailed(reason) {
            msExpiryTimer.stop()
            page.msError = reason
            page.msStatus = ""
        }
        function onMicrosoftLoginSucceeded(name) {
            msExpiryTimer.stop()
            msLoginPopup.close()
        }
    }

    Timer {
        id: msExpiryTimer
        interval: 1000
        repeat: true
        onTriggered: {
            if (page.msRemaining > 0) page.msRemaining--
            if (page.msRemaining <= 0) stop()
        }
    }

    property int selectedIndex: 0
    function current() {
        if (selectedIndex < 0 || selectedIndex >= accounts.count) return null
        return accounts.get(selectedIndex)
    }
    function currentId() { return current() ? current().internalId : "" }
    // Always a real bool (avoids "Unable to assign [undefined] to bool" while
    // the ListModel is being rebuilt).
    function currentIsOffline() { var c = current(); return !!c && c.kind === "Offline" }

    function makeDefault(i) {
        if (i < 0 || i >= accounts.count) return
        var id = accounts.get(i).internalId
        if (typeof App !== "undefined") App.setDefaultAccount(id)
    }
    // Clicking a row both selects it (shows its detail on the right) and makes
    // it the active account used for launching — i.e. "choose this profile".
    function selectAccount(i) {
        if (i < 0 || i >= accounts.count) return
        selectedIndex = i
        if (!accounts.get(i).isDefault) makeDefault(i)
        syncDetailSkin()
    }
    function remove(i) {
        if (i < 0 || i >= accounts.count) return
        var id = accounts.get(i).internalId
        if (typeof App !== "undefined") App.removeAccount(id)
    }

    function promptOfflineAccount() {
        addOfflinePopup.nameInput.text = ""
        // Default the new profile to a system skin so it has a face right away.
        createSkinPicker.selectedKey = "Steve"
        createSkinPicker.selectedVariant = "classic"
        addOfflinePopup.open()
    }

    // Opens the Microsoft sign-in popup and kicks off the device-code flow.
    // Restarting while a flow is already live is a no-op (the bridge keeps the
    // running one); restarting after a failure begins a fresh attempt.
    function openMicrosoftLogin() {
        msLink = ""
        msCode = ""
        msError = ""
        msRemaining = 0
        msStatus = qsTr("Connexion à Microsoft…")
        msLoginPopup.open()
        if (typeof App !== "undefined") App.startMicrosoftLogin()
    }

    // ===== Modal popup: rename offline account =====
    Popup {
        id: renamePopup
        property alias nameField: renameField
        property string targetId: ""
        modal: true
        focus: true
        anchors.centerIn: Overlay.overlay
        implicitWidth: 380
        implicitHeight: 220
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent
        background: Rectangle { color: Theme.bgElevated; radius: Theme.radiusLg; border.color: Theme.borderSubtle; border.width: 1 }
        Overlay.modal: Rectangle { color: Qt.rgba(0,0,0,0.45) }

        contentItem: ColumnLayout {
            spacing: 14
            Text {
                text: qsTr("Renommer le compte")
                color: Theme.textPrimary
                font.family: Theme.fontBody
                font.pointSize: 14
                font.weight: Font.Bold
            }
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 42
                radius: Theme.radiusMd
                color: Theme.bgInput
                border.color: renameField.activeFocus ? Theme.accentRing : Theme.borderSubtle
                border.width: 1
                Behavior on border.color { ColorAnimation { duration: Theme.durFast } }
                TextField {
                    id: renameField
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    color: Theme.textPrimary
                    font.family: Theme.fontBody
                    font.pointSize: 13
                    maximumLength: 16
                    background: null
                    verticalAlignment: TextInput.AlignVCenter
                    validator: RegExpValidator { regExp: /^[a-zA-Z0-9_]{0,16}$/ }
                    onAccepted: renameConfirm.tryRename()
                }
            }
            Item { Layout.fillHeight: true }
            Row {
                Layout.alignment: Qt.AlignRight
                spacing: 8
                IconButton { variant: "ghost"; text: qsTr("Annuler"); onClicked: renamePopup.close() }
                IconButton {
                    id: renameConfirm
                    variant: "primary"
                    iconName: "pencil"
                    text: qsTr("Renommer")
                    enabled: renameField.text.length >= 3
                    opacity: enabled ? 1 : 0.5
                    function tryRename() {
                        if (renameField.text.length < 3) return
                        if (typeof App !== "undefined")
                            App.renameOfflineAccount(renamePopup.targetId, renameField.text)
                        renamePopup.close()
                    }
                    onClicked: tryRename()
                }
            }
        }
    }

    // ===== Modal popup: create offline account =====
    Popup {
        id: addOfflinePopup
        property alias nameInput: nameField
        modal: true
        focus: true
        anchors.centerIn: Overlay.overlay
        implicitWidth: 420
        implicitHeight: 430
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent

        background: Rectangle {
            color: Theme.bgElevated
            radius: Theme.radiusLg
            border.color: Theme.borderSubtle
            border.width: 1
        }

        // Dim the rest of the window
        Overlay.modal: Rectangle {
            color: Qt.rgba(0, 0, 0, 0.45)
        }

        contentItem: ColumnLayout {
            spacing: 14

            Column {
                Layout.fillWidth: true
                spacing: 4
                Text {
                    text: qsTr("Ajouter un compte hors-ligne")
                    color: Theme.textPrimary
                    font.family: Theme.fontBody
                    font.pointSize: 14
                    font.weight: Font.Bold
                }
                Text {
                    text: qsTr("Choisis un pseudo. Pas besoin de compte Microsoft.")
                    color: Theme.textDim
                    font.family: Theme.fontBody
                    font.pointSize: 10
                    wrapMode: Text.WordWrap
                    width: parent.width
                }
            }

            Column {
                Layout.fillWidth: true
                spacing: 6

                Text {
                    text: qsTr("PSEUDO EN JEU")
                    color: Theme.textDim
                    font.family: Theme.fontBody
                    font.pointSize: 9
                    font.letterSpacing: 1
                    font.weight: Font.DemiBold
                }
                Rectangle {
                    width: parent.width
                    implicitHeight: 42
                    radius: Theme.radiusMd
                    color: Theme.bgInput
                    border.color: nameField.activeFocus ? Theme.accentRing : Theme.borderSubtle
                    border.width: 1
                    Behavior on border.color { ColorAnimation { duration: Theme.durFast } }

                    TextField {
                        id: nameField
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        placeholderText: qsTr("Karim_")
                        placeholderTextColor: Theme.textDim
                        color: Theme.textPrimary
                        font.family: Theme.fontBody
                        font.pointSize: 13
                        maximumLength: 16
                        background: null
                        verticalAlignment: TextInput.AlignVCenter
                        validator: RegExpValidator { regExp: /^[a-zA-Z0-9_]{0,16}$/ }
                        onAccepted: confirmBtn.tryCreate()
                    }
                }
                Text {
                    text: nameField.text.length === 0
                        ? qsTr("3 à 16 caractères — lettres, chiffres, underscore")
                        : (nameField.text.length < 3
                            ? qsTr("Encore %1 caractère(s)…").arg(3 - nameField.text.length)
                            : qsTr("✓ Nom valide"))
                    color: nameField.text.length >= 3 ? Theme.accentStrong : Theme.textDim
                    font.family: Theme.fontBody
                    font.pointSize: 10
                    Behavior on color { ColorAnimation { duration: Theme.durFast } }
                }
            }

            // Offline profile: only the bundled system skins are offered.
            SkinPicker {
                id: createSkinPicker
                Layout.fillWidth: true
                showNone: true
                systemOnly: true
            }

            Item { Layout.fillHeight: true }

            Row {
                Layout.alignment: Qt.AlignRight
                spacing: 8

                IconButton {
                    variant: "ghost"
                    text: qsTr("Annuler")
                    onClicked: addOfflinePopup.close()
                }
                IconButton {
                    id: confirmBtn
                    variant: "primary"
                    iconName: "user"
                    text: qsTr("Créer")
                    enabled: nameField.text.length >= 3
                    opacity: enabled ? 1 : 0.5
                    function tryCreate() {
                        if (nameField.text.length < 3) return
                        if (typeof App !== "undefined")
                            App.createOfflineAccount(nameField.text,
                                                     createSkinPicker.selectedKey,
                                                     createSkinPicker.selectedVariant)
                        addOfflinePopup.close()
                    }
                    onClicked: tryCreate()
                }
            }
        }
    }

    // ===== Modal popup: Microsoft sign-in (device code + QR) =====
    Popup {
        id: msLoginPopup
        modal: true
        focus: true
        anchors.centerIn: Overlay.overlay
        implicitWidth: 500
        implicitHeight: 460
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent
        onClosed: {
            msExpiryTimer.stop()
            // A finished sign-in already cleared the bridge state, so this is
            // a no-op then; it only drops an attempt the user walked away from.
            if (typeof App !== "undefined") App.cancelMicrosoftLogin()
        }

        background: Rectangle {
            color: Theme.bgElevated
            radius: Theme.radiusLg
            border.color: Theme.borderSubtle
            border.width: 1
        }
        Overlay.modal: Rectangle { color: Qt.rgba(0, 0, 0, 0.45) }

        contentItem: ColumnLayout {
            spacing: 14

            Column {
                Layout.fillWidth: true
                spacing: 4
                Text {
                    text: qsTr("Ajouter un compte Microsoft")
                    color: Theme.textPrimary
                    font.family: Theme.fontBody
                    font.pointSize: 14
                    font.weight: Font.Bold
                }
                Text {
                    width: parent.width
                    text: qsTr("Scanne le QR code avec ton téléphone (ou ouvre le lien), puis valide le code affiché sur l'écran.")
                    color: Theme.textDim
                    font.family: Theme.fontBody
                    font.pointSize: 10
                    wrapMode: Text.WordWrap
                }
            }

            // Waiting state: Microsoft did not hand us a code yet
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 10
                visible: page.msLink.length === 0 && page.msError.length === 0

                Item { Layout.preferredHeight: 40 }
                ProgressBar {
                    Layout.fillWidth: true
                    indeterminate: true
                    visible: page.msRunning
                }
                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: page.msStatus
                    color: Theme.textMuted
                    font.family: Theme.fontBody
                    font.pointSize: 10
                    wrapMode: Text.WordWrap
                }
                Item { Layout.preferredHeight: 40 }
            }

            // Code state: QR on the left, code + link on the right
            RowLayout {
                Layout.fillWidth: true
                spacing: 16
                visible: page.msLink.length > 0

                Rectangle {
                    implicitWidth: 158
                    implicitHeight: 158
                    radius: Theme.radiusMd
                    color: "white"
                    border.color: Theme.borderSubtle
                    border.width: 1

                    // Busy spinner until the QR renders (it is a one-shot image)
                    BusyIndicator {
                        anchors.centerIn: parent
                        running: page.msRunning && qrImage.status !== Image.Ready
                        visible: running
                    }
                    Image {
                        id: qrImage
                        anchors.centerIn: parent
                        width: 142
                        height: 142
                        source: (page.msLink.length > 0 && typeof App !== "undefined")
                            ? App.msaQrImageSource(page.msLink)
                            : ""
                        fillMode: Image.PreserveAspectFit
                        asynchronous: false
                        visible: status === Image.Ready
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    spacing: 6

                    Text {
                        text: qsTr("CODE À ENTRER")
                        color: Theme.textDim
                        font.family: Theme.fontBody
                        font.pointSize: 9
                        font.letterSpacing: 1
                        font.weight: Font.DemiBold
                    }
                    Text {
                        Layout.fillWidth: true
                        text: page.msCode
                        color: Theme.textPrimary
                        font.family: Theme.fontMono
                        font.pointSize: 20
                        font.weight: Font.Bold
                        elide: Text.ElideRight
                    }
                    Text {
                        text: page.msRemaining > 0
                            ? qsTr("Expire dans %1 s").arg(page.msRemaining)
                            : qsTr("Code expiré — demande-en un nouveau")
                        color: page.msRemaining > 0 ? Theme.textDim : Theme.accentRed
                        font.family: Theme.fontBody
                        font.pointSize: 9
                    }

                    Row {
                        spacing: 6
                        IconButton {
                            dense: true
                            variant: "filled"
                            iconName: "link"
                            text: qsTr("Ouvrir le lien")
                            onClicked: if (typeof App !== "undefined") App.openUrl(page.msLink)
                        }
                        IconButton {
                            dense: true
                            variant: "ghost"
                            iconName: "copy"
                            text: qsTr("Copier")
                            onClicked: if (typeof App !== "undefined") App.copyToClipboard(page.msLink)
                        }
                    }
                    Text {
                        Layout.fillWidth: true
                        text: page.msLink
                        color: Theme.textMuted
                        font.family: Theme.fontMono
                        font.pointSize: 8
                        elide: Text.ElideMiddle
                    }
                }
            }

            // Failure
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: msErrorText.implicitHeight + 24
                radius: Theme.radiusMd
                color: Qt.rgba(1, 0.3, 0.3, 0.10)
                border.color: Theme.accentRed
                border.width: 1
                visible: page.msError.length > 0
                Text {
                    id: msErrorText
                    anchors.fill: parent
                    anchors.margins: 12
                    text: page.msError
                    color: Theme.accentRed
                    font.family: Theme.fontBody
                    font.pointSize: 10
                    wrapMode: Text.WordWrap
                }
            }

            // Live status while waiting for the phone to confirm
            Text {
                Layout.fillWidth: true
                visible: page.msRunning && page.msError.length === 0
                horizontalAlignment: Text.AlignHCenter
                text: page.msStatus.length > 0
                    ? page.msStatus
                    : qsTr("En attente de validation sur ton appareil…")
                color: Theme.textMuted
                font.family: Theme.fontBody
                font.pointSize: 10
                wrapMode: Text.WordWrap
            }

            Item { Layout.fillHeight: true }

            Row {
                Layout.alignment: Qt.AlignRight
                spacing: 8
                IconButton {
                    variant: "ghost"
                    text: qsTr("Annuler")
                    onClicked: msLoginPopup.close()
                }
                IconButton {
                    visible: page.msError.length > 0
                    variant: "primary"
                    iconName: "link"
                    text: qsTr("Réessayer")
                    onClicked: page.openMicrosoftLogin()
                }
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        PageHeader {
            Layout.fillWidth: true
            iconName: "user"
            title: qsTr("Comptes")
            subtitle: accounts.count > 0
                ? qsTr("%1 compte(s) — gère tes profils en jeu").arg(accounts.count)
                : qsTr("Ajoute ton premier compte")
            onBack: page.back()
        }

        // ===== Body split =====
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            // ----- Left list -----
            Rectangle {
                Layout.preferredWidth: 300
                Layout.fillHeight: true
                color: Theme.bgSurface

                Rectangle {
                    anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
                    width: 1
                    color: Theme.borderSubtle
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 6

                    Text {
                        Layout.fillWidth: true
                        text: qsTr("TES COMPTES · %1").arg(accounts.count)
                        color: Theme.textDim
                        font.family: Theme.fontBody
                        font.pointSize: 9
                        font.letterSpacing: 1
                        font.weight: Font.DemiBold
                        Layout.bottomMargin: 4
                    }

                    // Empty state inside the left list
                    Column {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 8
                        visible: accounts.count === 0
                        Layout.topMargin: 16
                        Icon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            name: "user"
                            color: Theme.textDim
                            size: 36
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: qsTr("Aucun compte")
                            color: Theme.textMuted
                            font.family: Theme.fontBody
                            font.pointSize: 11
                            font.weight: Font.DemiBold
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: qsTr("Ajoute-en un avec les boutons ci-dessous.")
                            color: Theme.textDim
                            font.family: Theme.fontBody
                            font.pointSize: 9
                        }
                    }

                    ListView {
                        id: accountList
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        Layout.fillHeight: true
                        clip: true
                        spacing: 4
                        visible: accounts.count > 0
                        boundsBehavior: Flickable.StopAtBounds
                        model: accounts

                        delegate: Rectangle {
                            width: accountList.width
                            height: 58
                            radius: Theme.radiusMd
                            color: index === page.selectedIndex
                                ? Theme.accentSoft
                                : (rowHover.containsMouse ? Theme.bgElevated : "transparent")
                            border.color: index === page.selectedIndex ? Theme.accentRing : "transparent"
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: Theme.durFast } }

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 10

                                // Avatar (skin head when assigned, else initial)
                                SkinAvatar {
                                    implicitWidth: 36; implicitHeight: 36
                                    hasSkin: model.hasSkin
                                    source: page.avatarFor(model.internalId, model.hasSkin)
                                    fallbackText: model.initial
                                    fallbackBg: model.kind === "Offline"
                                        ? (index === page.selectedIndex ? Theme.accent : Theme.bgElevated)
                                        : Qt.rgba(0.13, 0.45, 0.93, 0.20)
                                    fallbackColor: model.kind === "Offline"
                                        ? (index === page.selectedIndex ? "white" : Theme.textPrimary)
                                        : "#7ab1ff"
                                }

                                Column {
                                    Layout.fillWidth: true
                                    spacing: 2
                                    Text {
                                        width: parent.width
                                        text: model.name
                                        color: Theme.textPrimary
                                        font.family: Theme.fontBody
                                        font.pointSize: 11
                                        font.weight: Font.DemiBold
                                        elide: Text.ElideRight
                                    }
                                    Row {
                                        spacing: 4
                                        Rectangle {
                                            radius: 4
                                            implicitHeight: 16
                                            implicitWidth: kbadge.implicitWidth + 10
                                            color: model.kind === "Offline"
                                                ? Theme.accentSoft
                                                : Qt.rgba(0.13, 0.45, 0.93, 0.18)
                                            Text {
                                                id: kbadge
                                                anchors.centerIn: parent
                                                text: model.kind.toUpperCase()
                                                color: model.kind === "Offline" ? Theme.accentStrong : "#7ab1ff"
                                                font.family: Theme.fontBody
                                                font.pointSize: 8
                                                font.weight: Font.Bold
                                            }
                                        }
                                    }
                                }
                            }

                            MouseArea {
                                id: rowHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: page.selectAccount(index)
                            }
                        }
                    }

                    // Divider
                    Rectangle { Layout.fillWidth: true; height: 1; color: Theme.borderSubtle; Layout.topMargin: 4; Layout.bottomMargin: 4 }

                    // Add buttons
                    IconButton {
                        Layout.fillWidth: true
                        variant: "primary"
                        iconName: "user"
                        text: qsTr("Ajouter compte hors-ligne")
                        onClicked: page.promptOfflineAccount()
                    }
                    IconButton {
                        Layout.fillWidth: true
                        variant: "filled"
                        iconName: "link"
                        text: qsTr("Ajouter un compte Microsoft")
                        onClicked: page.openMicrosoftLogin()
                    }
                }
            }

            // ----- Right detail -----
            ScrollView {
                id: detailScroll
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                ColumnLayout {
                    width: detailScroll.availableWidth
                    spacing: 22
                    Item { implicitHeight: 4 }

                    // Hero
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 32
                        Layout.rightMargin: 32
                        spacing: 22

                        // Avatar tile with accent halo
                        Item {
                            implicitWidth: 112; implicitHeight: 112
                            Rectangle {
                                anchors.centerIn: parent
                                width: 132; height: 132
                                radius: 66
                                color: page.current() && page.current().kind === "Offline"
                                    ? Theme.accentGlow2
                                    : Qt.rgba(0.13, 0.45, 0.93, 0.14)
                                opacity: 0.9
                            }
                            SkinAvatar {
                                anchors.fill: parent
                                hasSkin: page.current() ? page.current().hasSkin : false
                                source: page.current()
                                    ? page.avatarFor(page.current().internalId, page.current().hasSkin)
                                    : ""
                                fallbackText: page.current() ? page.current().initial : ""
                                fallbackColor: page.current() && page.current().kind === "Offline"
                                    ? Theme.accentStrong
                                    : "#7ab1ff"
                                fallbackBg: Theme.bgElevated
                            }
                        }

                        Column {
                            Layout.fillWidth: true
                            spacing: 4

                            Text {
                                text: page.current() ? page.current().name : ""
                                color: Theme.textPrimary
                                font.family: Theme.fontBody
                                font.pointSize: 24
                                font.weight: Font.Bold
                            }
                            Row {
                                spacing: 8
                                Rectangle {
                                    radius: 4
                                    implicitHeight: 18
                                    implicitWidth: heroKindLbl.implicitWidth + 12
                                    color: page.current() && page.current().kind === "Offline"
                                        ? Theme.accentSoft
                                        : Qt.rgba(0.13, 0.45, 0.93, 0.18)
                                    Text {
                                        id: heroKindLbl
                                        anchors.centerIn: parent
                                        text: page.current() ? qsTr("COMPTE %1").arg(page.current().kind.toUpperCase()) : ""
                                        color: page.current() && page.current().kind === "Offline" ? Theme.accentStrong : "#7ab1ff"
                                        font.family: Theme.fontBody
                                        font.pointSize: 9
                                        font.weight: Font.Bold
                                    }
                                }
                                Text {
                                    text: page.current() && page.current().kind === "Offline"
                                        ? qsTr("· Aucun token Mojang requis")
                                        : qsTr("· Sessions Mojang valides")
                                    color: Theme.textDim
                                    font.family: Theme.fontBody
                                    font.pointSize: 10
                                }
                            }
                        }
                    }

                    // Identifiers
                    Column {
                        Layout.leftMargin: 32
                        Layout.rightMargin: 32
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: qsTr("IDENTIFIANTS EN JEU")
                            color: Theme.textDim
                            font.family: Theme.fontBody
                            font.pointSize: 9
                            font.letterSpacing: 1
                            font.weight: Font.DemiBold
                        }

                        Row {
                            width: parent.width
                            spacing: 8
                            Rectangle {
                                width: (parent.width - 8) / 2
                                implicitHeight: 64
                                radius: Theme.radiusMd
                                color: Theme.bgSurface
                                border.color: Theme.borderSubtle
                                border.width: 1
                                Column {
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    spacing: 4
                                    Text { text: qsTr("Pseudo"); color: Theme.textDim; font.family: Theme.fontBody; font.pointSize: 9; font.letterSpacing: 0.5; font.weight: Font.DemiBold }
                                    Text { text: page.current() ? page.current().name : ""; color: Theme.textPrimary; font.family: Theme.fontMono; font.pointSize: 12 }
                                }
                            }
                            Rectangle {
                                width: (parent.width - 8) / 2
                                implicitHeight: 64
                                radius: Theme.radiusMd
                                color: Theme.bgSurface
                                border.color: Theme.borderSubtle
                                border.width: 1
                                Column {
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    spacing: 4
                                    Text { text: qsTr("UUID"); color: Theme.textDim; font.family: Theme.fontBody; font.pointSize: 9; font.letterSpacing: 0.5; font.weight: Font.DemiBold }
                                    Text {
                                        text: page.current()
                                            ? (page.current().uuid || "—")
                                            : "—"
                                        color: Theme.textPrimary
                                        font.family: Theme.fontMono
                                        font.pointSize: 10
                                        elide: Text.ElideRight
                                        width: parent.width
                                    }
                                }
                            }
                        }
                    }

                    // À savoir
                    Column {
                        Layout.leftMargin: 32
                        Layout.rightMargin: 32
                        Layout.fillWidth: true
                        spacing: 8
                        visible: page.currentIsOffline()

                        Text {
                            text: qsTr("À SAVOIR")
                            color: Theme.textDim
                            font.family: Theme.fontBody
                            font.pointSize: 9
                            font.letterSpacing: 1
                            font.weight: Font.DemiBold
                        }
                        Rectangle {
                            width: parent.width
                            implicitHeight: noteText.implicitHeight + 28
                            radius: Theme.radiusMd
                            color: Theme.bgSurface
                            border.color: Theme.borderSubtle
                            border.width: 1
                            Text {
                                id: noteText
                                anchors.fill: parent
                                anchors.margins: 14
                                text: qsTr("Ce compte ne fonctionne pas sur les serveurs publics (online-mode=true) comme Hypixel. Il marche en solo, en LAN, et sur les serveurs avec l'authentification désactivée.")
                                color: Theme.textMuted
                                font.family: Theme.fontBody
                                font.pointSize: 10
                                wrapMode: Text.WordWrap
                                textFormat: Text.PlainText
                            }
                        }
                    }

                    // Skin — offline profiles are limited to the bundled system
                    // skins; imported skins are reserved for online profiles.
                    Column {
                        Layout.leftMargin: 32
                        Layout.rightMargin: 32
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: qsTr("SKIN")
                            color: Theme.textDim
                            font.family: Theme.fontBody
                            font.pointSize: 9
                            font.letterSpacing: 1
                            font.weight: Font.DemiBold
                        }

                        Text {
                            visible: page.currentIsOffline()
                            width: parent.width
                            text: qsTr("Compte hors-ligne : seuls les skins système sont disponibles. Les skins importés sont réservés aux comptes en ligne.")
                            color: Theme.textMuted
                            font.family: Theme.fontBody
                            font.pointSize: 10
                            wrapMode: Text.WordWrap
                            textFormat: Text.PlainText
                        }

                        SkinPicker {
                            id: detailSkin
                            width: parent.width
                            showNone: true
                            systemOnly: page.currentIsOffline()
                            onPicked: function(key, variant) {
                                var c = page.current()
                                if (!c || typeof App === "undefined") return
                                if (key.length === 0)
                                    App.clearAccountSkin(c.internalId)
                                else
                                    App.setAccountSkin(c.internalId, key, variant)
                            }
                        }
                    }

                    // Actions
                    Column {
                        Layout.leftMargin: 32
                        Layout.rightMargin: 32
                        Layout.bottomMargin: 24
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: qsTr("ACTIONS")
                            color: Theme.textDim
                            font.family: Theme.fontBody
                            font.pointSize: 9
                            font.letterSpacing: 1
                            font.weight: Font.DemiBold
                        }

                        Row {
                            spacing: 8
                            IconButton {
                                variant: "filled"
                                iconName: "pencil"
                                text: qsTr("Renommer")
                                enabled: page.currentIsOffline()
                                opacity: enabled ? 1 : 0.4
                                onClicked: {
                                    var c = page.current()
                                    if (!c) return
                                    renamePopup.nameField.text = c.name
                                    renamePopup.targetId = c.internalId
                                    renamePopup.open()
                                }
                            }
                            IconButton {
                                // Microsoft accounts only: re-validate the stored
                                // tokens on demand (offline accounts have none).
                                visible: !page.currentIsOffline()
                                variant: "filled"
                                text: qsTr("Rafraîchir")
                                onClicked: {
                                    var c = page.current()
                                    if (!c || typeof App === "undefined") return
                                    App.refreshAccount(c.internalId)
                                }
                            }
                            IconButton {
                                variant: "danger"
                                iconName: "trash"
                                text: qsTr("Supprimer")
                                onClicked: page.remove(page.selectedIndex)
                            }
                        }
                    }
                }
            }
        }
    }
}
