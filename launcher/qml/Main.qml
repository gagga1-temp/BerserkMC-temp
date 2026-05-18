// SPDX-License-Identifier: Apache-2.0
// BerserkMC root QML window. Frameless shell + StackView routing across views.

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Window 2.15

import BerserkMC.Ui 1.0

import "components"
import "views"

ApplicationWindow {
    id: root
    width: 1100
    height: 700
    minimumWidth: 720
    minimumHeight: 480
    visible: true
    title: "BerserkMC"
    color: Theme.bgBase
    flags: Qt.Window | Qt.FramelessWindowHint | Qt.WindowSystemMenuHint
          | Qt.WindowMinMaxButtonsHint | Qt.WindowCloseButtonHint

    // Bridge-backed state. `App` is set as a context property from
    // Application::showQmlMainWindow().
    readonly property bool   hasAccount:  typeof App !== "undefined" && App.hasAccount
    readonly property string playerName:  typeof App !== "undefined" && App.defaultPlayer.length ? App.defaultPlayer : "Player"
    readonly property string accountKind: typeof App !== "undefined" && App.defaultKind.length ? App.defaultKind : "Offline"

    // The titlebar's subtitle reflects the current view for orientation.
    property string currentSection: "QML PREVIEW"

    Rectangle {
        anchors.fill: parent
        color: Theme.bgBase
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Titlebar {
            id: titlebar
            Layout.fillWidth: true
            subtitle: root.currentSection
            window: root
        }

        StackView {
            id: stack
            Layout.fillWidth: true
            Layout.fillHeight: true
            initialItem: root.hasAccount ? libraryComp : welcomeComp

            // React when the bridge's first account arrives — replace Welcome
            // with Library at runtime.
            Connections {
                target: typeof App !== "undefined" ? App : null
                function onAccountsChanged() {
                    if (root.hasAccount && stack.currentItem && stack.currentItem.toString().indexOf("Welcome") >= 0) {
                        stack.replace(libraryComp)
                    }
                }
            }

            // Push (forward) — new view slides in from the right
            pushEnter: Transition {
                ParallelAnimation {
                    NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.durMd; easing.type: Easing.OutCubic }
                    NumberAnimation { property: "x"; from: 30; to: 0; duration: Theme.durMd; easing.type: Easing.OutCubic }
                }
            }
            pushExit: Transition {
                NumberAnimation { property: "opacity"; from: 1; to: 0; duration: Theme.durFast }
            }
            // Pop (back) — restore the previous view; left exit slides
            popEnter: Transition {
                ParallelAnimation {
                    NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.durMd; easing.type: Easing.OutCubic }
                    NumberAnimation { property: "x"; from: -30; to: 0; duration: Theme.durMd; easing.type: Easing.OutCubic }
                }
            }
            popExit: Transition {
                ParallelAnimation {
                    NumberAnimation { property: "opacity"; from: 1; to: 0; duration: Theme.durFast }
                    NumberAnimation { property: "x"; from: 0; to: 30; duration: Theme.durFast }
                }
            }
            replaceEnter: Transition {
                ParallelAnimation {
                    NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.durMd; easing.type: Easing.OutCubic }
                    NumberAnimation { property: "x"; from: 30; to: 0; duration: Theme.durMd; easing.type: Easing.OutCubic }
                }
            }
            replaceExit: Transition {
                NumberAnimation { property: "opacity"; from: 1; to: 0; duration: Theme.durFast }
            }
        }
    }

    Component {
        id: welcomeComp
        WelcomeView {
            onOfflineAccountCreated: function(name) {
                if (typeof App !== "undefined")
                    App.createOfflineAccount(name)
                // StackView swap is driven by App.accountsChanged above so we
                // don't double-navigate.
            }
            onMicrosoftLoginRequested: {
                // Microsoft auth flow still routes through the existing cpp
                // AccountsDialog for now (Phase 7-B wires the QML version).
                console.log("ms login requested — Phase 7-B")
            }
        }
    }

    Component {
        id: libraryComp
        LibraryView {
            playerName:  root.playerName
            accountKind: root.accountKind
            onAccountsRequested:    stack.push(accountsComp)
            onSettingsRequested:    stack.push(settingsComp)
            onNewInstanceRequested: stack.push(newInstanceComp)
            onFoldersRequested:     console.log("open folders TODO")
        }
    }

    Component {
        id: accountsComp
        AccountsView { onBack: stack.pop() }
    }

    Component {
        id: newInstanceComp
        NewInstanceView {
            onBack: stack.pop()
            onCreated: function(name, version, loader) {
                console.log("create", name, version, loader)
                stack.pop()
            }
        }
    }

    Component {
        id: settingsComp
        SettingsView { onBack: stack.pop() }
    }

    onCurrentSectionChanged: titlebar.subtitle = currentSection

    // Reflect current view in the titlebar subtitle.
    Connections {
        target: stack
        function onCurrentItemChanged() {
            if (stack.currentItem instanceof Item) {
                if (stack.currentItem.toString().indexOf("Library") >= 0)
                    root.currentSection = "BIBLIOTHÈQUE"
                else if (stack.currentItem.toString().indexOf("Welcome") >= 0)
                    root.currentSection = "BIENVENUE"
            }
        }
    }

    // ===== Resize edges =====
    component Edge: MouseArea {
        property int edges
        hoverEnabled: true
        propagateComposedEvents: true
        cursorShape: {
            if (edges === (Qt.LeftEdge | Qt.TopEdge) || edges === (Qt.RightEdge | Qt.BottomEdge))
                return Qt.SizeFDiagCursor
            if (edges === (Qt.RightEdge | Qt.TopEdge) || edges === (Qt.LeftEdge | Qt.BottomEdge))
                return Qt.SizeBDiagCursor
            if (edges === Qt.LeftEdge || edges === Qt.RightEdge)
                return Qt.SizeHorCursor
            return Qt.SizeVerCursor
        }
        onPressed: if (root.visibility !== Window.Maximized) root.startSystemResize(edges)
    }
    Edge { width: 6; height: 6; anchors.left: parent.left;   anchors.top: parent.top;       edges: Qt.LeftEdge  | Qt.TopEdge }
    Edge { width: 6; height: 6; anchors.right: parent.right; anchors.top: parent.top;       edges: Qt.RightEdge | Qt.TopEdge }
    Edge { width: 6; height: 6; anchors.left: parent.left;   anchors.bottom: parent.bottom; edges: Qt.LeftEdge  | Qt.BottomEdge }
    Edge { width: 6; height: 6; anchors.right: parent.right; anchors.bottom: parent.bottom; edges: Qt.RightEdge | Qt.BottomEdge }
    Edge { height: 4; anchors.left: parent.left;   anchors.right: parent.right; anchors.top: parent.top;       anchors.leftMargin: 6; anchors.rightMargin: 6; edges: Qt.TopEdge }
    Edge { height: 4; anchors.left: parent.left;   anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.leftMargin: 6; anchors.rightMargin: 6; edges: Qt.BottomEdge }
    Edge { width: 4;  anchors.top: parent.top;     anchors.bottom: parent.bottom; anchors.left: parent.left;   anchors.topMargin: 6;  anchors.bottomMargin: 6; edges: Qt.LeftEdge }
    Edge { width: 4;  anchors.top: parent.top;     anchors.bottom: parent.bottom; anchors.right: parent.right; anchors.topMargin: 6;  anchors.bottomMargin: 6; edges: Qt.RightEdge }
}
