// SPDX-License-Identifier: Apache-2.0
#include "QmlBridge.h"

#include "Application.h"
#include "BuildConfig.h"
#include "minecraft/auth/AccountList.h"
#include "minecraft/auth/AccountTask.h"
#include "minecraft/auth/MinecraftAccount.h"
#include "InstanceList.h"
#include "BaseInstance.h"
#include "BaseVersionList.h"
#include "InstanceCreationTask.h"
#include "InstanceImportTask.h"
#include "minecraft/MinecraftInstance.h"
#include "meta/Index.h"
#include "meta/VersionList.h"
#include "meta/Version.h"
#include "minecraft/PackProfile.h"
#include "DesktopServices.h"
#include "settings/SettingsObject.h"
#include "FileSystem.h"
#include "java/JavaInstallList.h"
#include "java/JavaInstall.h"
#include "JavaInstaller.h"
#include "ui/dialogs/CopyInstanceDialog.h"
#include "ui/dialogs/ExportInstanceDialog.h"
#include "ui/dialogs/CreateShortcutDialog.h"
#include "ui/dialogs/CustomMessageBox.h"
#include "ui/dialogs/ProgressDialog.h"
#include "ui/dialogs/OfflineNameDialog.h"

#include "skins/SkinTypes.h"
#include "skins/SkinsModel.h"
#include "skins/SkinUtils.h"

#include <QAbstractListModel>
#include <QDebug>
#include <QFileInfo>
#include <QFileDialog>
#include <QRegularExpression>
#include <QDir>
#include <QSet>
#include <QUrl>
#include <QUrlQuery>
#include <QCoreApplication>
#include <QMessageBox>
#include <QStandardPaths>
#include <QProcess>
#include <QTimer>
#include <QClipboard>
#include <QGuiApplication>

namespace {
// BerserkMC: the local library mixes bundled system skins (shipped with the
// launcher) with skins imported by the user (PNG files). Offline profiles may
// only use the bundled system skins; imported skins are reserved for online
// profiles.
bool isSystemSkinKey(const QString &skinKey)
{
    if (skinKey.isEmpty()) {
        return false;
    }
    auto skins = APPLICATION ? APPLICATION->skinsModel() : nullptr;
    if (!skins) {
        return false;
    }
    const auto &entry = skins->skinEntry(skinKey);
    return !entry.isNull() && entry.internal;
}
} // namespace

QmlBridge::QmlBridge(QObject *parent) : QObject(parent)
{
    m_javaInstaller = new JavaInstaller(this);
    connect(m_javaInstaller, &JavaInstaller::started, this, [this](int v) {
        emit notification("info", tr("Installation Java %1 démarrée…").arg(v));
    });
    connect(m_javaInstaller, &JavaInstaller::finished, this,
            [this](int v, bool ok, const QString &path, const QString &err) {
        if (ok) {
            emit notification("ok", tr("Java %1 installé : %2").arg(v).arg(path));
        } else {
            emit notification("error", tr("Java %1: %2").arg(v).arg(err));
        }
    });
}

bool QmlBridge::javaIsInstalled(int majorVersion)
{
    return JavaInstaller::isInstalled(majorVersion);
}

QString QmlBridge::javaPathFor(int majorVersion)
{
    return JavaInstaller::javawPathFor(majorVersion);
}

void QmlBridge::installJava(int majorVersion)
{
    if (m_javaInstaller) m_javaInstaller->install(majorVersion);
}

AccountList* QmlBridge::accountList() const
{
    return APPLICATION->accounts().get();
}

InstanceList* QmlBridge::instanceList() const
{
    return APPLICATION->instances().get();
}

static QString tryAutoDetectJavaPath()
{
    // Best-effort: search PATH first, then well-known Adoptium/Eclipse Temurin /
    // Oracle / Microsoft / Azul layouts on Windows. Returns the first javaw.exe
    // that looks real. Empty on failure.
#ifdef Q_OS_WIN
    QStringList candidates;
    const QString jdkDirs[] = {
        "C:/Program Files/Eclipse Adoptium",
        "C:/Program Files/Eclipse Foundation",
        "C:/Program Files/Java",
        "C:/Program Files/Microsoft/jdk",
        "C:/Program Files/Zulu",
        "C:/Program Files/AdoptOpenJDK",
        "C:/Program Files (x86)/Java"
    };
    for (const QString &root : jdkDirs) {
        QDir d(root);
        if (!d.exists()) continue;
        for (const QString &child : d.entryList(QDir::Dirs | QDir::NoDotAndDotDot)) {
            candidates << d.filePath(child + "/bin/javaw.exe");
            candidates << d.filePath(child + "/jre/bin/javaw.exe");
        }
    }
    // Hard fallback: PATH lookup via QStandardPaths
    QString viaPath = QStandardPaths::findExecutable("javaw");
    if (!viaPath.isEmpty()) candidates.prepend(viaPath);

    for (const QString &p : candidates) {
        if (QFileInfo::exists(p)) return p;
    }
#endif
    return QString();
}

void QmlBridge::connectModels()
{
    // If the user has no JavaPath set, do a best-effort autodetect once and
    // persist the result. The Settings page will pick it up on next open.
    if (APPLICATION->settings()->get("JavaPath").toString().trimmed().isEmpty()) {
        QString found = tryAutoDetectJavaPath();
        if (!found.isEmpty()) {
            APPLICATION->settings()->set("JavaPath", found);
            emit notification("ok",
                tr("Java détecté : %1").arg(QFileInfo(found).absoluteFilePath()));
        }
    }

    auto a = accountList();
    if (a) {
        connect(a, &QAbstractListModel::modelReset,  this, &QmlBridge::onAccountsChanged);
        connect(a, &QAbstractListModel::rowsInserted,this, &QmlBridge::onAccountsChanged);
        connect(a, &QAbstractListModel::rowsRemoved, this, &QmlBridge::onAccountsChanged);
        connect(a, &QAbstractListModel::dataChanged, this, &QmlBridge::onAccountsChanged);
        connect(a, &AccountList::defaultAccountChanged, this, &QmlBridge::onAccountsChanged);
    }
    if (auto skins = APPLICATION ? APPLICATION->skinsModel() : nullptr) {
        connect(skins.get(), &SkinsModel::listUpdated, this, &QmlBridge::onSkinsChanged);
        connect(skins.get(), &SkinsModel::skinUpdated, this,
                [this](const QString &) { onSkinsChanged(); });
    }
    auto i = instanceList();
    if (i) {
        connect(i, &QAbstractListModel::modelReset,  this, &QmlBridge::onInstancesChanged);
        connect(i, &QAbstractListModel::rowsInserted,this, &QmlBridge::onInstancesChanged);
        connect(i, &QAbstractListModel::rowsRemoved, this, &QmlBridge::onInstancesChanged);
        connect(i, &QAbstractListModel::dataChanged, this, &QmlBridge::onInstancesChanged);
    }
    // Pipe launch outcomes back to QML as toast notifications + running-state
    // tracking. The bridge exposes a runningInstances QStringList so the
    // library can flip Play → Kill on the active card.
    connect(APPLICATION, &Application::instanceLaunchSucceeded, this,
            [this](const QString &id) {
                auto inst = APPLICATION->instances()->getInstanceById(id);
                QString name = inst ? inst->name() : id;
                emit notification("ok", tr("« %1 » lancé.").arg(name));
                if (m_runningInstances.removeAll(id) > 0)
                    emit runningInstancesChanged();
            });
    connect(APPLICATION, &Application::instanceLaunchFailed, this,
            [this](const QString &id, const QString &err) {
                auto inst = APPLICATION->instances()->getInstanceById(id);
                QString name = inst ? inst->name() : id;
                emit notification("error",
                    tr("Échec du lancement de « %1 » : %2").arg(name, err));
                if (m_runningInstances.removeAll(id) > 0)
                    emit runningInstancesChanged();
            });
    rebuildAccounts();
    rebuildInstances();
    rebuildSkins();
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
    m_defaultAccountId.clear();
    m_defaultAccountHasSkin = false;

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
        const bool offline = acc->isOffline();
        m["kind"]         = offline ? QStringLiteral("Offline") : QStringLiteral("Microsoft");
        m["offlineUuid"]  = acc->profileId();
        m["isDefault"]    = (def && def->internalId() == acc->internalId());
        // BerserkMC: locally-managed skin (empty when none assigned). Offline
        // profiles may only use the bundled system skins, so an imported skin
        // assigned to one is ignored (falls back to the initial avatar).
        QString skinKey = acc->getSkinKey();
        QByteArray skinData = acc->getSkin();
        if (offline && !skinData.isEmpty() && !isSystemSkinKey(skinKey)) {
            skinKey.clear();
            skinData.clear();
        }
        const bool hasSkin = !skinData.isEmpty();
        const bool slim = hasSkin && acc->getSkinModel() == Skins::Model::Slim;
        m["skinKey"]      = skinKey;
        m["skinVariant"]  = slim ? QStringLiteral("slim") : QStringLiteral("classic");
        m["hasSkin"]      = hasSkin;
        m_accounts.append(m);

        if (m["isDefault"].toBool()) {
            m_defaultPlayer = m["displayName"].toString();
            m_defaultKind   = m["kind"].toString();
            m_defaultAccountId = acc->internalId();
            m_defaultAccountHasSkin = hasSkin;
        }
    }
    if (m_defaultPlayer.isEmpty() && !m_accounts.isEmpty()) {
        m_defaultPlayer = m_accounts.first().toMap()["displayName"].toString();
        m_defaultKind   = m_accounts.first().toMap()["kind"].toString();
    }
    if (m_defaultAccountId.isEmpty() && !m_accounts.isEmpty()) {
        m_defaultAccountId = m_accounts.first().toMap()["internalId"].toString();
        m_defaultAccountHasSkin = m_accounts.first().toMap()["hasSkin"].toBool();
    }
}

void QmlBridge::rebuildSkins()
{
    m_skins.clear();
    auto skins = APPLICATION ? APPLICATION->skinsModel() : nullptr;
    if (!skins) return;

    for (int row = 0; row < skins->rowCount(); ++row) {
        const auto &entry = skins->at(row);
        if (entry.isNull()) continue;

        QVariantMap m;
        m["key"]      = entry.name;
        m["name"]     = entry.name;
        m["internal"] = entry.internal;
        // Both arm layouts are selectable for an imported (file-backed) skin:
        // the PNG is identical, only the in-game arm geometry differs. Bundled
        // system skins only expose the variants they actually ship.
        m["slim"]     = entry.internal ? bool(entry.slimVariant) : bool(entry.fileVariant);
        m["classic"]  = entry.internal ? bool(entry.classicVariant) : bool(entry.fileVariant);
        m_skins.append(m);
    }
}

void QmlBridge::onSkinsChanged()
{
    rebuildSkins();
    emit skinsChanged();
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

void QmlBridge::createOfflineAccount(const QString &playerName, const QString &skinKey, const QString &skinVariant)
{
    // Offline profiles accept 1–16 characters: Minecraft's 3-character minimum
    // only applies to online/Mojang names. The UI rejects empty/duplicate
    // pseudos before calling this.
    const QString name = playerName.trimmed();
    if (name.isEmpty() || name.size() > 16) {
        emit notification("error",
            tr("Pseudo invalide (16 caractères max)."));
        return;
    }
    auto acc = MinecraftAccount::createOffline(name);
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
        // A fresh profile is offline, so only a bundled system skin sticks here
        // (applySkinToAccount rejects imported skins for offline profiles).
        if (!skinKey.isEmpty()) {
            applySkinToAccount(acc, skinKey, skinVariant);
        }
        emit notification("ok", tr("Compte « %1 » créé.").arg(name));
    }
}

void QmlBridge::applySkinToAccount(const MinecraftAccountPtr &acc, const QString &skinKey, const QString &skinVariant)
{
    if (!acc || skinKey.isEmpty()) return;
    // Offline profiles only accept the bundled system skins.
    if (acc->isOffline() && !isSystemSkinKey(skinKey)) return;
    auto skins = APPLICATION ? APPLICATION->skinsModel() : nullptr;
    if (!skins) return;
    const auto &entry = skins->skinEntry(skinKey);
    if (entry.isNull()) return;
    const bool slim = skinVariant.compare(QLatin1String("slim"), Qt::CaseInsensitive) == 0;
    acc->setOfflineSkin(skinKey, slim,
                        entry.getTextureDataFor(slim ? Skins::Model::Slim : Skins::Model::Classic));
}

void QmlBridge::importSkin()
{
    auto skins = APPLICATION ? APPLICATION->skinsModel() : nullptr;
    if (!skins) return;

    const QStringList files = QFileDialog::getOpenFileNames(
        nullptr, tr("Importer un skin"), QString(),
        tr("Skins Minecraft (*.png)"));
    if (files.isEmpty()) return;

    int installed = 0;
    int failed = 0;
    for (const QString &path : files) {
        QFileInfo info(path);
        QFile file(path);
        if (!info.isFile() || !file.open(QIODevice::ReadOnly)) {
            ++failed;
            continue;
        }
        const QByteArray data = file.readAll();
        file.close();
        // Sanitise the key: alphanumerics, dash and underscore only.
        QString base = info.baseName();
        base.replace(QRegularExpression(QStringLiteral("[^A-Za-z0-9_-]")), QStringLiteral("_"));
        if (base.isEmpty()) base = QStringLiteral("skin");
        if (skins->installSkin(data, base).isValid()) {
            ++installed;
        } else {
            ++failed;
        }
    }

    if (installed > 0) {
        emit notification("ok",
            tr("%n skin(s) importé(s).", "", installed));
    }
    if (failed > 0) {
        emit notification("warning",
            tr("%n fichier(s) ignoré(s) (format invalide).", "", failed));
    }
}

bool QmlBridge::deleteSkin(const QString &skinKey)
{
    auto skins = APPLICATION ? APPLICATION->skinsModel() : nullptr;
    if (!skins) return false;
    if (!skins->skinFileExists(skinKey)) {
        emit notification("error", tr("Skin introuvable."));
        return false;
    }
    // Only locally-imported (file-backed) skins can be deleted; the bundled
    // system skins are read-only resources.
    if (skins->skinEntry(skinKey).internal) {
        emit notification("error", tr("Les skins système ne peuvent pas être supprimés."));
        return false;
    }
    const bool ok = skins->deleteSkin(skinKey);
    if (ok) {
        // Refresh immediately; the file watcher also fires a directoryChanged.
        skins->directoryChanged(skins->path());
        emit notification("ok", tr("Skin « %1 » supprimé.").arg(skinKey));
    } else {
        emit notification("error", tr("Suppression impossible."));
    }
    return ok;
}

void QmlBridge::setAccountSkin(const QString &internalId, const QString &skinKey, const QString &skinVariant)
{
    MinecraftAccountPtr acc;
    int row = -1;
    if (!APPLICATION->accounts()->getAccountById(internalId, acc, row) || !acc) {
        emit notification("error", tr("Compte introuvable."));
        return;
    }
    if (skinKey.isEmpty()) {
        clearAccountSkin(internalId);
        return;
    }

    auto skins = APPLICATION->skinsModel();
    const auto &entry = skins->skinEntry(skinKey);
    if (entry.isNull()) {
        emit notification("error", tr("Skin « %1 » introuvable.").arg(skinKey));
        return;
    }
    // Offline profiles are limited to the bundled system skins; imported skins
    // are reserved for online profiles.
    if (acc->isOffline() && !entry.internal) {
        emit notification("error", tr("Les skins importés sont réservés aux comptes en ligne."));
        return;
    }
    const bool slim = skinVariant.compare(QLatin1String("slim"), Qt::CaseInsensitive) == 0;
    acc->setOfflineSkin(skinKey, slim,
                        entry.getTextureDataFor(slim ? Skins::Model::Slim : Skins::Model::Classic));
    emit notification("ok", tr("Skin appliqué à « %1 ».").arg(acc->profileName()));
}

void QmlBridge::clearAccountSkin(const QString &internalId)
{
    MinecraftAccountPtr acc;
    int row = -1;
    if (!APPLICATION->accounts()->getAccountById(internalId, acc, row) || !acc) return;
    acc->setOfflineSkin(QString(), false, QByteArray());
    emit notification("ok", tr("Skin retiré."));
}

QString QmlBridge::skinsDirectory() const
{
    auto skins = APPLICATION ? APPLICATION->skinsModel() : nullptr;
    return skins ? skins->path() : QString();
}

void QmlBridge::openSkinsFolder()
{
    const QString dir = skinsDirectory();
    if (dir.isEmpty()) return;
    QDir().mkpath(dir);
    DesktopServices::openDirectory(dir);
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
    // `offline` is only the caller's request: LaunchController::login() has the
    // final word and always forces an offline session for local offline
    // accounts, while a Microsoft account honours an online request.
    bool ok = APPLICATION->launch(inst, !offline, nullptr, nullptr, nullptr, QString());
    if (ok) {
        emit notification("info", tr("Lancement de « %1 »…").arg(inst->name()));
        if (!m_runningInstances.contains(instanceId)) {
            m_runningInstances.append(instanceId);
            emit runningInstancesChanged();
        }
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
    // Carry the locally-managed skin over to the recreated account (offline
    // profiles only ever hold a bundled system skin).
    const QString skinKey = acc->getSkinKey();
    const QByteArray skinData = acc->getSkin();
    if (!skinData.isEmpty()) {
        fresh->setOfflineSkin(skinKey, acc->getSkinModel() == Skins::Model::Slim, skinData);
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

void QmlBridge::refreshAccount(const QString &internalId)
{
    MinecraftAccountPtr acc;
    int row;
    if (!APPLICATION->accounts()->getAccountById(internalId, acc, row) || !acc) {
        emit notification("error", tr("Compte introuvable."));
        return;
    }
    if (acc->isOffline()) {
        emit notification("info", tr("Un compte hors-ligne n'a aucun jeton à rafraîchir."));
        return;
    }
    if (acc->isActive()) {
        return;
    }
    auto task = acc->refresh();
    if (!task) {
        emit notification("error", tr("Impossible de rafraîchir ce compte."));
        return;
    }
    auto *raw = task.get();
    connect(raw, &Task::succeeded, this, [this]() {
        emit notification("ok", tr("Compte Microsoft rafraîchi."));
    });
    connect(raw, &Task::failed, this, [this](const QString &reason) {
        emit notification("error", reason.isEmpty() ? tr("Échec du rafraîchissement du compte.") : reason);
    });
    task->start();
}

void QmlBridge::startMicrosoftLogin()
{
    if (m_msLoginRunning) {
        return;
    }
    auto account = MinecraftAccount::createBlankMSA();
    if (!account) {
        emit microsoftLoginFailed(tr("Impossible de préparer la connexion Microsoft."));
        return;
    }
    auto task = account->loginMSA();
    if (!task) {
        emit microsoftLoginFailed(tr("Impossible de démarrer la connexion Microsoft."));
        return;
    }
    m_msLoginAccount = account;
    m_msLoginTask = task;
    m_msLoginRunning = true;
    emit microsoftLoginRunningChanged(true);
    emit microsoftLoginStatus(tr("Connexion à Microsoft…"));

    auto *raw = task.get();
    connect(raw, &Task::status, this, [this, raw](const QString &status) {
        if (m_msLoginTask.get() == raw) emit microsoftLoginStatus(status);
    });
    connect(raw, &Task::progress, this, [this, raw](qint64 current, qint64 total) {
        if (m_msLoginTask.get() == raw) emit microsoftLoginProgress(current, total);
    });
    // Device-code step: `uri` is the verification page, `code` the short form
    // to type by hand. The link gets the code appended (?otc=) so opening it
    // lands on an already-filled page, like the QR does.
    connect(raw, &AccountTask::showVerificationUriAndCode, this,
            [this, raw](const QUrl &uri, const QString &code, int expiresIn) {
        if (m_msLoginTask.get() != raw) return;
        QUrl link = uri;
        QUrlQuery query;
        query.addQueryItem(QStringLiteral("otc"), code);
        link.setQuery(query);
        emit microsoftLoginVerification(link.toString(), code, expiresIn);
    });
    connect(raw, &Task::failed, this, [this, raw](const QString &reason) {
        if (m_msLoginTask.get() != raw) return;
        const bool wasRunning = m_msLoginRunning;
        finishMicrosoftLogin();
        if (wasRunning) emit microsoftLoginFailed(reason);
    });
    connect(raw, &Task::succeeded, this, [this, raw]() {
        if (m_msLoginTask.get() != raw) return;
        MinecraftAccountPtr signedIn = m_msLoginAccount;
        const bool wasRunning = m_msLoginRunning;
        finishMicrosoftLogin();
        if (!wasRunning || !signedIn) return;
        auto list = APPLICATION->accounts();
        list->addAccount(signedIn);
        if (!list->defaultAccount()) {
            list->setDefaultAccount(signedIn);
        }
        const QString name = signedIn->profileName().isEmpty() ? signedIn->gamerTag()
                                                               : signedIn->profileName();
        emit microsoftLoginSucceeded(name);
        emit notification("ok", tr("Compte Microsoft « %1 » ajouté.").arg(name));
    });
    task->start();
}

void QmlBridge::cancelMicrosoftLogin()
{
    if (!m_msLoginRunning) {
        return;
    }
    finishMicrosoftLogin();
}

void QmlBridge::finishMicrosoftLogin()
{
    // The task reads the account's data, so drop the task first. `.reset()`
    // (not `= nullptr`) so no empty control block is built on the way out.
    m_msLoginTask.reset();
    m_msLoginAccount.reset();
    if (m_msLoginRunning) {
        m_msLoginRunning = false;
        emit microsoftLoginRunningChanged(false);
    }
}

QString QmlBridge::msaQrImageSource(const QString &text) const
{
    // Hex instead of percent-encoding: the payload survives any URL
    // normalization Qt applies before it reaches the image provider.
    return QStringLiteral("image://msaqr/") + QString::fromLatin1(text.toUtf8().toHex());
}

void QmlBridge::openUrl(const QString &url)
{
    const QUrl parsed(url);
    if (!parsed.isValid()) {
        emit notification("error", tr("Lien invalide."));
        return;
    }
    DesktopServices::openUrl(parsed);
}

void QmlBridge::copyToClipboard(const QString &text)
{
    QGuiApplication::clipboard()->setText(text);
    emit notification("ok", tr("Lien copié."));
}

void QmlBridge::showOfflineNameDialog()
{
    QString lastName = APPLICATION->settings()->get("LastOfflinePlayerName").toString();
    OfflineNameDialog dialog(lastName, nullptr);
    if (dialog.exec() == OfflineNameDialog::Accepted) {
        const QString name = dialog.textValue();
        APPLICATION->settings()->set("LastOfflinePlayerName", name);
        emit notification("info", tr("Nom de joueur hors ligne enregistré : %1").arg(name));
    }
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
    emit notification("info", tr("Création de « %1 »…").arg(name));
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

    // Pre-check : le loader choisi doit exister pour cette version de Minecraft.
    if (!loader.isEmpty() && loader != "Aucun") {
        if (!loaderAvailable(version, loader)) {
            emit notification("error", tr("Aucune version de %1 pour Minecraft %2.").arg(loader, version));
            return false;
        }
    }

    auto task = new InstanceCreationTask(baseVer);
    task->setName(name);
    task->setGroup(APPLICATION->settings()->get("LastUsedGroupForNewInstance").toString());
    task->setIcon("default");

    // Remember which instances exist so the one we just created can be
    // identified by its id — instance names are not unique.
    QSet<QString> idsBefore;
    auto il = APPLICATION->instances();
    for (int i = 0; i < il->rowCount(QModelIndex()); ++i) {
        if (auto inst = il->at(i))
            idsBefore.insert(inst->id());
    }

    unique_qobject_ptr<Task> wrapped(il->wrapInstanceTask(task));
    ProgressDialog dlg(nullptr);
    int rc = dlg.execWithTask(wrapped.get());
    if (rc != QDialog::Accepted) {
        emit notification("error", tr("Création annulée ou échouée."));
        return false;
    }

    // Identify the instance that was just committed (id not present before).
    InstancePtr created;
    for (int i = 0; i < il->rowCount(QModelIndex()); ++i) {
        auto inst = il->at(i);
        if (inst && !idsBefore.contains(inst->id())) { created = inst; break; }
    }
    if (!created) {
        emit notification("error", tr("Instance créée mais introuvable."));
        return false;
    }

    // Optional mod-loader install. Resolve the loader list and pin the newest
    // build that targets the chosen Minecraft version into the new instance.
    QString loaderUid;
    if      (loader == "Fabric")   loaderUid = "net.fabricmc.fabric-loader";
    else if (loader == "Forge")    loaderUid = "net.minecraftforge";
    else if (loader == "Quilt")    loaderUid = "org.quiltmc.quilt-loader";
    else if (loader == "NeoForge") loaderUid = "net.neoforged";

    if (loaderUid.isEmpty()) {
        emit notification("ok", tr("Instance « %1 » créée.").arg(name));
        return true;
    }

    auto mcInst = std::dynamic_pointer_cast<MinecraftInstance>(created);
    if (!mcInst) {
        emit notification("error", tr("Instance non-Minecraft, loader ignoré."));
        return true;
    }
    auto profile = mcInst->getPackProfile();
    if (!profile) {
        emit notification("error", tr("PackProfile manquant — loader ignoré."));
        return true;
    }

    auto loaderList = idx->get(loaderUid);
    if (!loaderList) {
        emit notification("error", tr("Liste %1 indisponible.").arg(loader));
        return true;
    }
    if (!loaderList->isLoaded()) {
        auto loadTask = loaderList->getLoadTask();
        if (loadTask) {
            ProgressDialog ld(nullptr);
            ld.execWithTask(loadTask.get());
        }
    }
    if (loaderList->count() == 0) {
        emit notification("error", tr("Pas de versions de %1.").arg(loader));
        return true;
    }

    // Newest loader build that targets this Minecraft version. Fabric/Quilt
    // advertise no parent version (empty) and therefore match any game version.
    BaseVersionPtr latest;
    for (int i = 0; i < loaderList->count(); ++i) {
        auto candidate = loaderList->at(i);
        if (!candidate) continue;
        const QString parent = loaderList
            ->data(loaderList->index(i, 0), BaseVersionList::ParentVersionRole)
            .toString();
        if (parent.isEmpty() || parent == version) {
            latest = candidate;
            break;
        }
    }
    if (!latest) {
        emit notification("error",
            tr("Aucune version de %1 pour Minecraft %2.").arg(loader, version));
        return true;
    }

    // A freshly committed instance hands out a PackProfile that has not been
    // read from disk yet. An unloaded profile silently drops every save (see
    // PackProfile::scheduleSave), so the loader we pin below would never reach
    // mmc-pack.json and the instance would launch as vanilla. Load (and
    // resolve) the real profile first — the same step the classic instance
    // page performs before touching components.
    profile->reload(Net::Mode::Online);
    if (auto loadTask = profile->getCurrentTask()) {
        ProgressDialog ld(nullptr);
        ld.execWithTask(loadTask.get());
    }

    if (!profile->setComponentVersion(loaderUid, latest->descriptor(), true)) {
        emit notification("error", tr("Impossible d'ajouter %1 au profil.").arg(loader));
        return true;
    }
    // setComponentVersion only records the choice; resolve() fetches the
    // component metadata and its libraries for the freshly created instance.
    profile->resolve(Net::Mode::Online);
    if (auto updateTask = profile->getCurrentTask()) {
        ProgressDialog ld(nullptr);
        int rc = ld.execWithTask(updateTask.get());
        if (rc != QDialog::Accepted) {
            emit notification("error", tr("Échec de l'installation de %1 (téléchargement des libs).").arg(loader));
            return true;
        }
    }
    // Persiste le pack sur disque pour que le loader soit bien présent au lancement.
    profile->saveNow();
    mcInst->saveNow();
    emit notification("ok", tr("Instance « %1 » + %2 %3 installé.")
                              .arg(name, loader, latest->descriptor()));
    return true;
}

QVariantMap QmlBridge::loaderVersionFilter(const QString &loader)
{
    QVariantMap out;
    out["ok"] = true;
    out["all"] = true;
    out["versions"] = QStringList();

    QString uid;
    if      (loader == "Fabric")   uid = "net.fabricmc.fabric-loader";
    else if (loader == "Forge")    uid = "net.minecraftforge";
    else if (loader == "Quilt")    uid = "org.quiltmc.quilt-loader";
    else if (loader == "NeoForge") uid = "net.neoforged";
    else return out; // "Aucun" / inconnu: aucun filtrage

    auto idx = APPLICATION ? APPLICATION->metadataIndex() : nullptr;
    if (!idx) { out["ok"] = false; return out; }
    auto vl = idx->get(uid);
    if (!vl) { out["ok"] = false; return out; }

    if (!vl->isLoaded()) {
        auto task = vl->getLoadTask();
        if (task) {
            QEventLoop loop;
            QObject::connect(task.get(), &Task::succeeded, &loop, &QEventLoop::quit);
            QObject::connect(task.get(), &Task::failed, &loop, &QEventLoop::quit);
            task->start();
            loop.exec();
        }
    }
    if (!vl->isLoaded()) { out["ok"] = false; return out; }

    QStringList supported;
    for (int i = 0; i < vl->count(); ++i) {
        auto cand = vl->at(i);
        if (!cand) continue;
        const QString parent = vl->data(vl->index(i, 0), BaseVersionList::ParentVersionRole).toString();
        if (parent.isEmpty()) {
            // No pinned Minecraft version: the loader advertises support for
            // every version (Fabric/Quilt ship this way).
            out["all"] = true;
            return out;
        }
        if (!supported.contains(parent)) supported.append(parent);
    }
    out["all"] = false;
    out["versions"] = supported;
    return out;
}

bool QmlBridge::loaderAvailable(const QString &mcVersion, const QString &loader)
{
    QVariantMap filter = loaderVersionFilter(loader);
    if (!filter.value("ok").toBool()) return true; // inconnu -> ne pas bloquer
    if (filter.value("all").toBool()) return true;
    return filter.value("versions").toStringList().contains(mcVersion);
}

QString QmlBridge::pickImportFile()
{
    return QFileDialog::getOpenFileName(nullptr, tr("Choisir un modpack"), QString(), tr("Modpacks (*.zip *.mrpack);;Tous les fichiers (*)"));
}

bool QmlBridge::importInstance(const QString &source)
{
    if (source.trimmed().isEmpty()) {
        emit notification("error", tr("Source manquante (URL ou fichier)."));
        return false;
    }
    auto il = APPLICATION ? APPLICATION->instances() : nullptr;
    if (!il) {
        emit notification("error", tr("Liste d'instances indisponible."));
        return false;
    }

    QUrl url(source.trimmed());
    if (url.isLocalFile() == false && !url.isRelative() && url.scheme().isEmpty()) {
        // treat as local path
        url = QUrl::fromLocalFile(source.trimmed());
    }
    if (url.isLocalFile() == false && url.scheme().isEmpty()) {
        url = QUrl::fromLocalFile(source.trimmed());
    }

    auto task = new InstanceImportTask(url);
    QSet<QString> idsBefore;
    for (int i = 0; i < il->rowCount(QModelIndex()); ++i) {
        if (auto inst = il->at(i)) idsBefore.insert(inst->id());
    }

    unique_qobject_ptr<Task> wrapped(il->wrapInstanceTask(task));
    ProgressDialog dlg(nullptr);
    emit notification("info", tr("Import en cours…"));
    int rc = dlg.execWithTask(wrapped.get());
    if (rc != QDialog::Accepted) {
        emit notification("error", tr("Import annulé ou échoué."));
        return false;
    }

    InstancePtr created;
    for (int i = 0; i < il->rowCount(QModelIndex()); ++i) {
        auto inst = il->at(i);
        if (inst && !idsBefore.contains(inst->id())) { created = inst; break; }
    }
    if (created) {
        emit notification("ok", tr("Instance « %1 » importée.").arg(created->name()));
    } else {
        emit notification("ok", tr("Import terminé."));
    }
    return true;
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
    // The changelog ships next to the binary (install layout) but a dev build
    // may not have one there — fall back to the data folder, then give up with
    // a visible error instead of silently opening a missing file.
    QStringList candidates = {
        QDir(QCoreApplication::applicationDirPath()).absoluteFilePath("changelog.md"),
        QDir(APPLICATION->root()).absoluteFilePath("changelog.md"),
    };
    for (const QString &path : candidates) {
        if (QFileInfo::exists(path)) {
            DesktopServices::openUrl(QUrl::fromLocalFile(path));
            return;
        }
    }
    emit notification("error", tr("Changelog introuvable sur cette installation."));
}

void QmlBridge::checkForUpdates()
{
    // L'auto-updater (projet BerserkMCUpdater) vit a cote du launcher. Le bouton
    // manuel lance Updater.exe sans argument : code 10 = une mise a jour existe,
    // on le relance alors avec notre PID, on quitte pour liberer les fichiers et
    // l'updater installe puis redemarre. Il connait deja le depot BerserkMC.
    const QString updater = QDir(QCoreApplication::applicationDirPath()).absoluteFilePath("Updater.exe");
    if (!QFileInfo::exists(updater)) {
        emit notification("error", tr("Auto-update indisponible : Updater.exe introuvable à côté du launcher."));
        return;
    }
    if (m_updateCheck) {
        return; // une vérification est déjà en cours
    }

    m_updateCheck = new QProcess(this);
#ifdef Q_OS_WIN
    // Évite qu'une console clignote pendant la simple vérification (mode silencieux).
    m_updateCheck->setCreateProcessArgumentsModifier([](QProcess::CreateProcessArguments *args) {
#ifndef CREATE_NO_WINDOW
#define CREATE_NO_WINDOW 0x08000000
#endif
        args->flags |= CREATE_NO_WINDOW;
    });
#endif
    connect(m_updateCheck,
            static_cast<void (QProcess::*)(int, QProcess::ExitStatus)>(&QProcess::finished),
            this, [this](int exitCode, QProcess::ExitStatus exitStatus) {
        if (m_updateCheck) {
            m_updateCheck->deleteLater();
            m_updateCheck = nullptr;
        }
        if (exitStatus != QProcess::NormalExit) {
            emit notification("error", tr("La vérification des mises à jour a échoué."));
            return;
        }
        if (exitCode == 0) {
            emit notification("ok", tr("BerserkMC est déjà à jour."));
            return;
        }
        if (exitCode == 10) {
            const QString updater =
                QDir(QCoreApplication::applicationDirPath()).absoluteFilePath("Updater.exe");
            emit notification("info", tr("Mise à jour disponible, installation puis redémarrage…"));
            const QStringList updaterArgs = { QString::number(QCoreApplication::applicationPid()) };
            if (!QProcess::startDetached(updater, updaterArgs)) {
                emit notification("error", tr("Impossible de lancer l'auto-updater."));
                return;
            }
            // Laisse la notification s'afficher, puis quitte pour liberer les fichiers :
            // l'updater attend notre PID avant de remplacer quoi que ce soit.
            QTimer::singleShot(1500, []() { QCoreApplication::quit(); });
            return;
        }
        emit notification("error", tr("Vérification impossible (code %1).").arg(exitCode));
    });

    emit notification("info", tr("Recherche de mises à jour…"));
    m_updateCheck->start(updater, QStringList());
}

QString QmlBridge::launcherRoot() const
{
    return APPLICATION ? APPLICATION->root() : QString();
}

QString QmlBridge::launcherVersion() const
{
    return BuildConfig.printableVersionString();
}

QVariantList QmlBridge::minecraftVersions()
{
    auto idx = APPLICATION ? APPLICATION->metadataIndex() : nullptr;
    if (!idx) return m_mcVersions;
    auto vl = idx->get("net.minecraft");
    if (!vl) return m_mcVersions;

    // Only (re)start a load when we are neither already loading nor in a failed
    // state. Without the failed guard a failing download (e.g. a broken TLS
    // backend) would be retried in an endless loop from onVersionListChanged.
    if (!vl->isLoaded() && !m_mcVersionsLoading && !m_mcVersionsFailed) {
        m_mcVersionsLoading = true;
        auto task = vl->getLoadTask();
        if (task) {
            connect(task.get(), &Task::succeeded, this, &QmlBridge::onMinecraftVersionsLoaded);
            connect(task.get(), &Task::failed, this, &QmlBridge::onMinecraftVersionsFailed);
            task->start();
        } else {
            // Nothing to run and still not loaded: report failure instead of
            // leaving the UI stuck on a spinner forever.
            m_mcVersionsLoading = false;
            m_mcVersionsFailed = true;
            emit versionListChanged();
        }
    }
    // load() parses the local meta file synchronously, so the data may already
    // be available even while a remote refresh is still running.
    if (vl->isLoaded() && !m_mcVersionsLoaded) {
        m_mcVersionsLoaded = true;
        m_mcVersionsLoading = false;
        m_mcVersionsFailed = false;
        rebuildMinecraftVersions();
        emit versionListChanged();
    }
    return m_mcVersions;
}

void QmlBridge::onMinecraftVersionsLoaded()
{
    m_mcVersionsLoading = false;
    m_mcVersionsLoaded = true;
    m_mcVersionsFailed = false;
    rebuildMinecraftVersions();
    emit versionListChanged();
}

void QmlBridge::onMinecraftVersionsFailed()
{
    m_mcVersionsLoading = false;
    m_mcVersionsFailed = true;
    rebuildMinecraftVersions();
    emit versionListChanged();
}

void QmlBridge::retryMinecraftVersions()
{
    // Called from the "Réessayer" button: clear the failed latch so the next
    // minecraftVersions() call is allowed to start a fresh download.
    m_mcVersionsFailed = false;
    m_mcVersionsLoaded = false;
    m_mcVersionsLoading = false;
    emit versionListChanged();
}

void QmlBridge::rebuildMinecraftVersions()
{
    m_mcVersions.clear();
    auto idx = APPLICATION ? APPLICATION->metadataIndex() : nullptr;
    if (!idx) return;
    auto vl = idx->get("net.minecraft");
    if (!vl || !vl->isLoaded()) return;

    const auto versions = vl->versions();
    m_mcVersions.reserve(versions.size());
    for (const auto &v : versions) {
        if (!v) continue;
        QVariantMap m;
        m["id"]   = v->descriptor();
        m["type"] = v->type();
        m["time"] = v->rawTime(); // epoch milliseconds, humanised in QML
        m_mcVersions.append(m);
    }
}

#include <QFileDialog>

void QmlBridge::detectJava()
{
    auto list = APPLICATION->javalist();
    if (!list) {
        emit notification("error", tr("Java install list indisponible."));
        return;
    }
    emit notification("info", tr("Scan des installations Java en cours…"));
    auto task = list->getLoadTask();
    if (!task) return;
    auto self = this;
    QObject::connect(task.get(), &Task::succeeded, this, [self, list]() {
        emit self->notification("ok",
            tr("Scan terminé — %1 Java détecté(s).").arg(list->count()));
    });
    QObject::connect(task.get(), &Task::failed, this, [self](QString err) {
        emit self->notification("error", tr("Scan Java échoué : %1").arg(err));
    });
    task->start();
}

QString QmlBridge::browseForJava()
{
    QString filter =
#ifdef Q_OS_WIN
        "Java (javaw.exe);;Tous les fichiers (*)";
#else
        "Java executables (java);;All files (*)";
#endif
    QString start = APPLICATION->settings()->get("JavaPath").toString();
    QString picked = QFileDialog::getOpenFileName(
        nullptr,
        tr("Choisis l'exécutable Java"),
        start,
        filter);
    if (!picked.isEmpty()) {
        APPLICATION->settings()->set("JavaPath", picked);
    }
    return picked;
}
