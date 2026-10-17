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

    // Quit-on-last-window-closed is disabled in C++ (Application.cpp) and this
    // QML shell is not wired to the legacy Widgets close path, so without this
    // the process would keep running after the window is closed. Quitting here
    // only ends the launcher; a running Minecraft process is spawn-detached and
    // keeps going.
    onClosing: Qt.quit()

    // Bridge-backed state. `App` is set as a context property from
    // Application::showQmlMainWindow().
    readonly property bool   hasAccount:  typeof App !== "undefined" && App.hasAccount
    readonly property string playerName:  typeof App !== "undefined" && App.defaultPlayer.length ? App.defaultPlayer : "Player"
    readonly property string accountKind: typeof App !== "undefined" && App.defaultKind.length ? App.defaultKind : "Offline"

    // The titlebar's subtitle reflects the current view for orientation. It is
    // filled in by the StackView's onCurrentItemChanged below, so it starts
    // empty rather than showing a placeholder.
    property string currentSection: ""

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
            onOfflineAccountCreated: function(name, skinKey, skinVariant) {
                if (typeof App !== "undefined")
                    App.createOfflineAccount(name, skinKey, skinVariant)
                // StackView swap is driven by App.accountsChanged above so we
                // don't double-navigate.
            }
        }
    }

    Component {
        id: libraryComp
        LibraryView {
            playerName:  root.playerName
            accountKind: root.accountKind
            onAccountsRequested:    stack.push(accountsComp)
            onSkinsRequested:       stack.push(skinsComp)
            onSettingsRequested:    stack.push(settingsComp)
            onNewInstanceRequested: stack.push(newInstanceComp)
            onFoldersRequested: {
                if (typeof App !== "undefined") App.openFolder("launcher")
            }
        }
    }

    Component {
        id: accountsComp
        AccountsView { onBack: stack.pop() }
    }

    Component {
        id: skinsComp
        SkinsView { onBack: stack.pop() }
    }

    Component {
        id: newInstanceComp
        NewInstanceView {
            onBack: stack.pop()
            onCreated: function(name, version, loader) {
                if (typeof App !== "undefined")
                    App.createVanillaInstance(name, version, loader)
                stack.pop()
            }
        }
    }

    Component {
        id: settingsComp
        SettingsView { onBack: stack.pop() }
    }

    onCurrentSectionChanged: titlebar.subtitle = currentSection

    // Each view exposes `viewTitle` so the titlebar always reflects the
    // active screen without us hard-coding names here.
    Connections {
        target: stack
        function onCurrentItemChanged() {
            var item = stack.currentItem
            if (item && item.viewTitle && item.viewTitle.length)
                root.currentSection = item.viewTitle
        }
    }

    // Toast overlay — always above the StackView, listens to App.notification.
    Toast {
        id: toastLayer
    }

    Component.onCompleted: {
        if (typeof App !== "undefined") {
            // Restore persisted accent color before any view paints itself.
            var savedAccent = App.getSetting("AccentHex", "")
            if (savedAccent && savedAccent.length)
                Theme.setAccent(savedAccent)
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
