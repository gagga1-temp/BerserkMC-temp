// SPDX-License-Identifier: Apache-2.0
#include "QmlBridge.h"

#include "Application.h"
#include "minecraft/auth/AccountList.h"
#include "minecraft/auth/MinecraftAccount.h"
#include "InstanceList.h"
#include "BaseInstance.h"
#include "InstanceCreationTask.h"
#include "minecraft/MinecraftInstance.h"
#include "meta/Index.h"
#include "meta/VersionList.h"
#include "meta/Version.h"
#include "DesktopServices.h"
#include "settings/SettingsObject.h"
#include "FileSystem.h"
#include "ui/dialogs/CopyInstanceDialog.h"
#include "ui/dialogs/ExportInstanceDialog.h"
#include "ui/dialogs/CreateShortcutDialog.h"
#include "ui/dialogs/CustomMessageBox.h"
#include "ui/dialogs/ProgressDialog.h"

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
    // Pipe launch outcomes back to QML as toast notifications.
    connect(APPLICATION, &Application::instanceLaunchSucceeded, this,
            [this](const QString &id) {
                emit notification("ok", tr("« %1 » terminé.").arg(id));
            });
    connect(APPLICATION, &Application::instanceLaunchFailed, this,
            [this](const QString &id, const QString &err) {
                emit notification("error",
                    tr("Échec du lancement de « %1 » : %2").arg(id, err));
            });
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

        // Crude mod count: list .jar / .jar.disabled files under <gameRoot>/mods.
        // Fast and avoids spinning up the full ModFolderModel just for the badge.
        int mods = 0;
        auto mc = std::dynamic_pointer_cast<MinecraftInstance>(inst);
        if (mc) {
            QDir modsDir(mc->modsRoot());
            if (modsDir.exists()) {
                QStringList filters; filters << "*.jar" << "*.jar.disabled" << "*.litemod";
                mods = modsDir.entryList(filters, QDir::Files | QDir::NoDotAndDotDot).size();
            }
        }
        m["mods"] = mods;

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
    bool ok = APPLICATION->launch(inst, !offline, nullptr, nullptr, nullptr, QString());
    if (ok) {
        emit notification("info", tr("Lancement de « %1 »…").arg(inst->name()));
    } else {
        emit notification("error",
            tr("Impossible de lancer « %1 ». Vérifie Java / le compte sélectionné.")
                .arg(inst->name()));
    }
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
    Q_UNUSED(loader); // mod-loader install is a TODO; vanilla wires today.
    if (name.trimmed().isEmpty() || version.trimmed().isEmpty()) {
        emit notification("error", tr("Nom ou version manquant."));
        return false;
    }

    // Resolve the BaseVersion via the metadata index. We have to wait for the
    // net.minecraft VersionList to load before .getVersion() returns anything.
    auto idx = APPLICATION->metadataIndex();
    if (!idx) {
        emit notification("error", tr("Index de versions indisponible."));
        return false;
    }
    auto vList = idx->get("net.minecraft");
    if (!vList) {
        emit notification("error", tr("Liste des versions Minecraft introuvable."));
        return false;
    }

    if (!vList->isLoaded()) {
        // Trigger the load + retry once it lands. Toast immediately so the
        // user knows something is happening.
        emit notification("info", tr("Chargement de la liste des versions…"));
        auto loadTask = vList->getLoadTask();
        if (loadTask) {
            QString capturedName = name;
            QString capturedVersion = version;
            QString capturedLoader = loader;
            QObject::connect(loadTask.get(), &Task::succeeded, this,
                [this, capturedName, capturedVersion, capturedLoader]() {
                    createVanillaInstance(capturedName, capturedVersion, capturedLoader);
                });
            QObject::connect(loadTask.get(), &Task::failed, this,
                [this](QString err) {
                    emit notification("error", tr("Index versions: %1").arg(err));
                });
            loadTask->start();
        }
        return false;
    }

    auto baseVer = vList->getVersion(version);
    if (!baseVer) {
        emit notification("error", tr("Version %1 introuvable dans le manifest.").arg(version));
        return false;
    }

    auto task = new InstanceCreationTask(baseVer);
    task->setName(name);
    task->setGroup(APPLICATION->settings()->get("LastUsedGroupForNewInstance").toString());
    task->setIcon("default");

    // Wrap with the InstanceList so the new instance is registered, then run
    // it modally so the user sees the download progress.
    unique_qobject_ptr<Task> wrapped(APPLICATION->instances()->wrapInstanceTask(task));
    ProgressDialog dlg(nullptr);
    int rc = dlg.execWithTask(wrapped.get());
    if (rc == QDialog::Accepted) {
        emit notification("ok", tr("Instance « %1 » créée.").arg(name));
        return true;
    }
    emit notification("error", tr("Création annulée ou échouée."));
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
