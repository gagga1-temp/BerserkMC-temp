// SPDX-License-Identifier: Apache-2.0
#include "QmlBridge.h"

#include "Application.h"
#include "minecraft/auth/AccountList.h"
#include "minecraft/auth/MinecraftAccount.h"
#include "InstanceList.h"
#include "BaseInstance.h"
#include "minecraft/MinecraftInstance.h"
#include "DesktopServices.h"
#include "settings/SettingsObject.h"
#include "FileSystem.h"
#include "ui/dialogs/CopyInstanceDialog.h"
#include "ui/dialogs/ExportInstanceDialog.h"
#include "ui/dialogs/CreateShortcutDialog.h"
#include "ui/dialogs/CustomMessageBox.h"

#include <QAbstractListModel>
#include <QDebug>
#include <QFileInfo>
#include <QDir>
#include <QMessageBox>

QmlBridge::QmlBridge(QObject *parent) : QObject(parent) {}

AccountList* QmlBridge::accountList() const
{
    return APPLICATION->accounts().get();
}

InstanceList* QmlBridge::instanceList() const
{
    return APPLICATION->instances().get();
}

void QmlBridge::connectModels()
{
    auto a = accountList();
    if (a) {
        connect(a, &QAbstractListModel::modelReset,  this, &QmlBridge::onAccountsChanged);
        connect(a, &QAbstractListModel::rowsInserted,this, &QmlBridge::onAccountsChanged);
        connect(a, &QAbstractListModel::rowsRemoved, this, &QmlBridge::onAccountsChanged);
        connect(a, &QAbstractListModel::dataChanged, this, &QmlBridge::onAccountsChanged);
        connect(a, &AccountList::defaultAccountChanged, this, &QmlBridge::onAccountsChanged);
    }
    auto i = instanceList();
    if (i) {
        connect(i, &QAbstractListModel::modelReset,  this, &QmlBridge::onInstancesChanged);
        connect(i, &QAbstractListModel::rowsInserted,this, &QmlBridge::onInstancesChanged);
        connect(i, &QAbstractListModel::rowsRemoved, this, &QmlBridge::onInstancesChanged);
        connect(i, &QAbstractListModel::dataChanged, this, &QmlBridge::onInstancesChanged);
    }
    rebuildAccounts();
    rebuildInstances();
}

void QmlBridge::onAccountsChanged()
{
    rebuildAccounts();
    emit accountsChanged();
}

void QmlBridge::onInstancesChanged()
{
    rebuildInstances();
    emit instancesChanged();
}

void QmlBridge::rebuildAccounts()
{
    m_accounts.clear();
    m_defaultPlayer.clear();
    m_defaultKind.clear();

    auto a = accountList();
    if (!a) return;

    auto def = a->defaultAccount();
    for (int row = 0; row < a->count(); ++row) {
        const auto &entry = a->at(row);
        if (!entry.isAccount || !entry.account) continue;
        auto acc = entry.account;

        QVariantMap m;
        m["internalId"]   = acc->internalId();
        m["profileName"]  = acc->profileName();
        m["gamerTag"]     = acc->gamerTag();
        m["displayName"]  = acc->profileName().isEmpty() ? acc->gamerTag() : acc->profileName();
        m["kind"]         = acc->isOffline() ? QStringLiteral("Offline") : QStringLiteral("Microsoft");
        m["isDefault"]    = (def && def->internalId() == acc->internalId());
        m["stateText"]    = acc->accountStateText();
        m["ownsMinecraft"]= acc->ownsMinecraft();
        m["hasProfile"]   = acc->hasProfile();
        m_accounts.append(m);

        if (m["isDefault"].toBool()) {
            m_defaultPlayer = m["displayName"].toString();
            m_defaultKind   = m["kind"].toString();
        }
    }
    if (m_defaultPlayer.isEmpty() && !m_accounts.isEmpty()) {
        m_defaultPlayer = m_accounts.first().toMap()["displayName"].toString();
        m_defaultKind   = m_accounts.first().toMap()["kind"].toString();
    }
}

void QmlBridge::rebuildInstances()
{
    m_instances.clear();
    auto il = instanceList();
    if (!il) return;

    for (int row = 0; row < il->rowCount(QModelIndex()); ++row) {
        auto inst = il->at(row);
        if (!inst) continue;

        QVariantMap m;
        m["id"]          = inst->id();
        m["name"]        = inst->name();
        m["iconKey"]     = inst->iconKey();
        m["group"]       = il->getInstanceGroup(inst->id());
        m["mcVersion"]   = inst->getStatusbarDescription();
        m["lastPlayed"]  = inst->lastLaunch();
        m["totalPlayed"] = inst->totalTimePlayed();
        m["lastTimePlayed"] = inst->lastTimePlayed();
        m_instances.append(m);
    }
}

void QmlBridge::createOfflineAccount(const QString &playerName)
{
    if (playerName.size() < 3 || playerName.size() > 16) {
        emit notification("error",
            tr("Le pseudo doit faire entre 3 et 16 caractères."));
        return;
    }
    auto acc = MinecraftAccount::createOffline(playerName);
    if (!acc) {
        emit notification("error", tr("Échec création compte hors-ligne."));
        return;
    }
    auto idx = APPLICATION->accounts()->addAccount(acc);
    if (idx.isValid()) {
        // Promote to default if it's the first account.
        if (APPLICATION->accounts()->count() == 1
            || !APPLICATION->accounts()->defaultAccount()) {
            APPLICATION->accounts()->setDefaultAccount(acc);
        }
        emit notification("ok", tr("Compte « %1 » créé.").arg(playerName));
    }
}

void QmlBridge::setDefaultAccount(const QString &internalId)
{
    MinecraftAccountPtr acc;
    int row;
    if (APPLICATION->accounts()->getAccountById(internalId, acc, row)) {
        APPLICATION->accounts()->setDefaultAccount(acc);
    }
}

void QmlBridge::removeAccount(const QString &internalId)
{
    APPLICATION->accounts()->removeAccount(internalId);
}

void QmlBridge::launchInstance(const QString &instanceId, bool offline)
{
    auto inst = APPLICATION->instances()->getInstanceById(instanceId);
    if (!inst) {
        emit notification("error", tr("Instance introuvable: %1").arg(instanceId));
        return;
    }
    APPLICATION->launch(inst, !offline, nullptr, nullptr, nullptr, QString());
}

void QmlBridge::renameOfflineAccount(const QString &internalId, const QString &newName)
{
    MinecraftAccountPtr acc;
    int row;
    if (!APPLICATION->accounts()->getAccountById(internalId, acc, row) || !acc) {
        emit notification("error", tr("Compte introuvable."));
        return;
    }
    if (!acc->isOffline()) {
        emit notification("error", tr("Seuls les comptes hors-ligne sont renommables."));
        return;
    }
    if (newName.size() < 3 || newName.size() > 16) {
        emit notification("error", tr("Pseudo invalide (3 à 16 caractères)."));
        return;
    }
    // Recreate offline acc with new name + restore default flag, then drop old.
    auto fresh = MinecraftAccount::createOffline(newName);
    if (!fresh) {
        emit notification("error", tr("Renommage échoué."));
        return;
    }
    const bool wasDefault = (APPLICATION->accounts()->defaultAccount()
                              && APPLICATION->accounts()->defaultAccount()->internalId() == internalId);
    APPLICATION->accounts()->removeAccount(internalId);
    auto idx = APPLICATION->accounts()->addAccount(fresh);
    if (idx.isValid() && wasDefault) {
        APPLICATION->accounts()->setDefaultAccount(fresh);
    }
    emit notification("ok", tr("Renommé en « %1 ».").arg(newName));
}

void QmlBridge::showAccountsDialog()
{
    APPLICATION->ShowAccountsDialog(nullptr);
}

void QmlBridge::killInstance(const QString &instanceId)
{
    auto inst = APPLICATION->instances()->getInstanceById(instanceId);
    if (inst) APPLICATION->kill(inst);
}

void QmlBridge::editInstance(const QString &instanceId, const QString &page)
{
    auto inst = APPLICATION->instances()->getInstanceById(instanceId);
    if (!inst) return;
    APPLICATION->showInstanceWindow(inst, page);
}

void QmlBridge::viewMods(const QString &instanceId)          { editInstance(instanceId, "mods"); }
void QmlBridge::viewWorlds(const QString &instanceId)        { editInstance(instanceId, "worlds"); }
void QmlBridge::manageScreenshots(const QString &instanceId) { editInstance(instanceId, "screenshots"); }
void QmlBridge::editNotes(const QString &instanceId)         { editInstance(instanceId, "notes"); }

void QmlBridge::duplicateInstance(const QString &instanceId)
{
    auto inst = APPLICATION->instances()->getInstanceById(instanceId);
    if (!inst) return;
    CopyInstanceDialog dlg(inst, nullptr);
    dlg.exec();
}

void QmlBridge::exportInstance(const QString &instanceId)
{
    auto inst = APPLICATION->instances()->getInstanceById(instanceId);
    if (!inst) return;
    ExportInstanceDialog dlg(inst, nullptr);
    dlg.exec();
}

void QmlBridge::createShortcut(const QString &instanceId)
{
    auto inst = APPLICATION->instances()->getInstanceById(instanceId);
    if (!inst) return;
    CreateShortcutDialog dlg(nullptr, inst);
    dlg.exec();
}

void QmlBridge::deleteInstance(const QString &instanceId)
{
    auto inst = APPLICATION->instances()->getInstanceById(instanceId);
    if (!inst) return;
    auto answer = CustomMessageBox::selectable(
        nullptr,
        tr("Supprimer l'instance ?"),
        tr("Tu es sur le point de supprimer « %1 ». Cette opération est définitive.\n\nContinuer ?")
            .arg(inst->name()),
        QMessageBox::Warning,
        QMessageBox::Yes | QMessageBox::No,
        QMessageBox::No
    )->exec();
    if (answer == QMessageBox::Yes) {
        APPLICATION->instances()->deleteInstance(instanceId);
        emit notification("ok", tr("Instance supprimée."));
    }
}

bool QmlBridge::createVanillaInstance(const QString &name, const QString &version, const QString &loader)
{
    // Phase 7-D placeholder — wiring the full InstanceCreationTask + loader
    // install means re-implementing chunks of NewInstanceDialog. Surface a
    // notification so QML at least confirms the action ran end-to-end.
    Q_UNUSED(loader);
    emit notification("info",
        tr("Création de « %1 » (Minecraft %2) — pas encore branché au cpp.")
            .arg(name, version));
    return false;
}

void QmlBridge::openFolder(const QString &kind)
{
    // "<kind>" or "<kind>:<instanceId>"
    QString k = kind;
    QString instId;
    int sep = kind.indexOf(':');
    if (sep >= 0) {
        k = kind.left(sep);
        instId = kind.mid(sep + 1);
    }

    if (k == "launcher") {
        DesktopServices::openDirectory(APPLICATION->root());
        return;
    }
    if (k == "central-mods") {
        DesktopServices::openDirectory(APPLICATION->settings()->get("CentralModsDir").toString());
        return;
    }
    if (k == "instances-root") {
        DesktopServices::openDirectory(APPLICATION->settings()->get("InstanceDir").toString());
        return;
    }

    if (instId.isEmpty()) return;
    auto inst = APPLICATION->instances()->getInstanceById(instId);
    if (!inst) return;

    if (k == "instance") {
        DesktopServices::openDirectory(inst->instanceRoot());
    } else if (k == "minecraft" || k == "mods" || k == "worlds" || k == "screenshots") {
        auto mc = std::dynamic_pointer_cast<MinecraftInstance>(inst);
        if (!mc) return;
        if (k == "minecraft")        DesktopServices::openDirectory(mc->gameRoot());
        else if (k == "mods")        DesktopServices::openDirectory(mc->modsRoot());
        else if (k == "worlds")      DesktopServices::openDirectory(mc->worldDir());
        else                          DesktopServices::openDirectory(FS::PathCombine(mc->gameRoot(), "screenshots"));
    }
}

QVariant QmlBridge::getSetting(const QString &key, const QVariant &fallback)
{
    auto v = APPLICATION->settings()->get(key);
    return v.isValid() ? v : fallback;
}

void QmlBridge::setSetting(const QString &key, const QVariant &value)
{
    APPLICATION->settings()->set(key, value);
}

void QmlBridge::openChangelog()
{
    DesktopServices::openUrl(QUrl::fromLocalFile(
        QDir(APPLICATION->root()).absoluteFilePath("changelog.md")));
}
