// SPDX-License-Identifier: Apache-2.0
#include "QmlBridge.h"

#include "Application.h"
#include "minecraft/auth/AccountList.h"
#include "minecraft/auth/MinecraftAccount.h"
#include "InstanceList.h"
#include "BaseInstance.h"

#include <QAbstractListModel>
#include <QDebug>

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
