// SPDX-License-Identifier: Apache-2.0
// Bridges the cpp Application state (accounts, instances, launch) to QML
// without touching the existing model classes. QML accesses everything via
// the singleton `App` context property.

#pragma once

#include <QObject>
#include <QVariantList>
#include <QString>

#include "minecraft/auth/MinecraftAccount.h"

class Application;
class AccountList;
class InstanceList;
class QProcess;

class QmlBridge : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QVariantList accounts        READ accounts        NOTIFY accountsChanged)
    Q_PROPERTY(QVariantList instances       READ instances       NOTIFY instancesChanged)
    Q_PROPERTY(bool         hasAccount      READ hasAccount      NOTIFY accountsChanged)
    Q_PROPERTY(QString      defaultPlayer   READ defaultPlayer   NOTIFY accountsChanged)
    Q_PROPERTY(QString      defaultKind     READ defaultKind     NOTIFY accountsChanged)
    Q_PROPERTY(QString      defaultAccountId READ defaultAccountId NOTIFY accountsChanged)
    Q_PROPERTY(bool         defaultAccountHasSkin READ defaultAccountHasSkin NOTIFY accountsChanged)
    Q_PROPERTY(QVariantList skins           READ skins           NOTIFY skinsChanged)
    Q_PROPERTY(QStringList  runningInstances READ runningInstances NOTIFY runningInstancesChanged)

public:
    explicit QmlBridge(QObject *parent = nullptr);

    QVariantList accounts() const  { return m_accounts; }
    QVariantList instances() const { return m_instances; }
    bool hasAccount() const        { return !m_accounts.isEmpty(); }
    QString defaultPlayer() const  { return m_defaultPlayer; }
    QString defaultKind() const    { return m_defaultKind; }
    QString defaultAccountId() const { return m_defaultAccountId; }
    bool defaultAccountHasSkin() const { return m_defaultAccountHasSkin; }
    QVariantList skins() const     { return m_skins; }
    QStringList runningInstances() const { return m_runningInstances; }

    // Called by Application once accounts/instances are loaded.
    void rebuildAccounts();
    void rebuildInstances();
    void rebuildSkins();
    void connectModels();

public:
    Q_INVOKABLE bool javaIsInstalled(int majorVersion);
    Q_INVOKABLE QString javaPathFor(int majorVersion);
    Q_INVOKABLE void installJava(int majorVersion);

public slots:
    // Accounts
    void createOfflineAccount(const QString &playerName,
                              const QString &skinKey = QString(),
                              const QString &skinVariant = QString());
    void setDefaultAccount(const QString &internalId);
    void removeAccount(const QString &internalId);
    void renameOfflineAccount(const QString &internalId, const QString &newName);
    void showAccountsDialog();         // opens the cpp AccountsDialog (offline-only, MSA login disabled)
    void showOfflineNameDialog();      // debug: opens the OfflineNameDialog on demand

    // Skins (locally-managed library)
    void importSkin();                 // native file picker -> SkinsModel
    bool deleteSkin(const QString &skinKey);
    void setAccountSkin(const QString &internalId, const QString &skinKey, const QString &skinVariant);
    void clearAccountSkin(const QString &internalId);
    QString skinsDirectory() const;
    void openSkinsFolder();

    // Instance lifecycle
    void launchInstance(const QString &instanceId, bool offline = false);
    void killInstance(const QString &instanceId);
    void editInstance(const QString &instanceId, const QString &page = QString());
    void viewMods(const QString &instanceId);
    void viewWorlds(const QString &instanceId);
    void manageScreenshots(const QString &instanceId);
    void editNotes(const QString &instanceId);
    void duplicateInstance(const QString &instanceId);
    void exportInstance(const QString &instanceId);
    void createShortcut(const QString &instanceId);
    void deleteInstance(const QString &instanceId);
    bool createVanillaInstance(const QString &name, const QString &version, const QString &loader);

    // Folder shortcuts (kind: "launcher" | "instance:<id>" | "minecraft:<id>" |
    //   "mods:<id>" | "worlds:<id>" | "screenshots:<id>")
    void openFolder(const QString &kind);

    // Settings get/set (string round-trips through QVariant)
    QVariant getSetting(const QString &key, const QVariant &fallback = QVariant());
    void     setSetting(const QString &key, const QVariant &value);
    void     openChangelog();
    void     checkForUpdates();        // manual auto-updater trigger (Updater.exe next to the binary)
    QString  browseForJava();   // opens a native file picker, returns path or ""
    void     detectJava();      // scans the system for Java installs (Adoptium/etc.)
    Q_INVOKABLE QString launcherRoot() const; // data folder shown in the settings UI
    Q_INVOKABLE QString launcherVersion() const; // human-readable version shown in the About section

    // Minecraft version catalogue, sourced from the cpp meta index so it shares
    // a single source of truth with instance creation (and honours the local
    // meta cache instead of hitting Mojang directly).
    Q_INVOKABLE QVariantList minecraftVersions();
    Q_INVOKABLE bool minecraftVersionsLoading() const { return m_mcVersionsLoading; }
    Q_INVOKABLE bool minecraftVersionsFailed() const { return m_mcVersionsFailed; }
    Q_INVOKABLE void retryMinecraftVersions();

signals:
    void accountsChanged();
    void instancesChanged();
    void skinsChanged();
    void runningInstancesChanged();
    void versionListChanged();
    void notification(const QString &kind, const QString &message);

private slots:
    void onAccountsChanged();
    void onInstancesChanged();
    void onSkinsChanged();
    void onMinecraftVersionsLoaded();
    void onMinecraftVersionsFailed();

private:
    QVariantList m_accounts;
    QVariantList m_instances;
    QVariantList m_skins;
    QString m_defaultPlayer;
    QString m_defaultKind;
    QString m_defaultAccountId;
    bool m_defaultAccountHasSkin = false;
    QStringList m_runningInstances;
    QVariantList m_mcVersions;
    bool m_mcVersionsLoading = false;
    bool m_mcVersionsLoaded = false;
    bool m_mcVersionsFailed = false;
    QProcess *m_updateCheck = nullptr;

    void rebuildMinecraftVersions();

    AccountList* accountList() const;
    InstanceList* instanceList() const;

    // BerserkMC: resolve a library skin and apply it to a profile. Offline
    // profiles only accept the bundled system skins (imported skins are
    // reserved for online profiles), so this is a no-op otherwise.
    void applySkinToAccount(const MinecraftAccountPtr &acc, const QString &skinKey, const QString &skinVariant);

    class JavaInstaller* m_javaInstaller = nullptr;
};
