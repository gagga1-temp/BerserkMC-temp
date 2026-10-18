// SPDX-License-Identifier: Apache-2.0
#include "JavaInstaller.h"

#include "Application.h"
#include "FileSystem.h"

#include <QNetworkAccessManager>
#include <QNetworkRequest>
#include <QNetworkReply>
#include <QFile>
#include <QFileInfo>
#include <QDir>
#include <QDirIterator>
#include <QHash>
#include <QPointer>
#include <QUrl>
#include <QStandardPaths>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QDebug>

#include <JlCompress.h>

namespace {
constexpr const char *kAdoptiumApi =
    "https://api.adoptium.net/v3/binary/latest/%1/ga/windows/x64/jdk/hotspot/normal/eclipse?project=jdk";

// Only one install per major version may run at a time. Launch tasks and the
// settings page can all ask for the same runtime at once; running two downloads
// (or two extractions) into the same folder corrupts the result.
QHash<int, JavaInstaller *> g_installsInFlight;

QString findJavawIn(const QString &root)
{
    QDir base(root);
    if (!base.exists()) return QString();
    // Temurin extracts as jdk-<full version>/bin/javaw.exe under our prefix.
    const auto subs = base.entryList(QDir::Dirs | QDir::NoDotAndDotDot);
    for (const auto &sub : subs) {
        QString candidate = base.filePath(sub + "/bin/javaw.exe");
        if (QFileInfo::exists(candidate)) return candidate;
    }
    // Fallback: maybe the zip extracted flat
    QString flat = base.filePath("bin/javaw.exe");
    if (QFileInfo::exists(flat)) return flat;
    return QString();
}

bool fileAt(const QString &base, const char *rel)
{
    return QFileInfo::exists(base + QLatin1Char('/') + QLatin1String(rel));
}

// A launcher-managed runtime is only usable when the whole JVM payload is on
// disk. Checking javaw.exe alone accepts a half extracted folder, and the
// launcher would then keep using that broken Java for every launch.
bool isValidRuntime(const QString &javaw)
{
    if (javaw.isEmpty()) return false;
    const QFileInfo fi(javaw);
    if (!fi.exists()) return false;

    QDir binDir = fi.dir();
    QDir jdkDir = binDir;
    if (!jdkDir.cdUp()) return false;
    const QString base = jdkDir.absolutePath();

    // jvm.cfg lives in lib/ since Java 9, and in jre/lib/amd64 on Java 8.
    const bool hasCfg = fileAt(base, "lib/jvm.cfg")
                        || fileAt(base, "lib/amd64/jvm.cfg")
                        || fileAt(base, "jre/lib/amd64/jvm.cfg")
                        || fileAt(base, "jre/lib/jvm.cfg")
                        || fileAt(base, "jre/lib/server/jvm.cfg");
    if (!hasCfg) {
        QDirIterator it(base, QStringList() << QStringLiteral("jvm.cfg"),
                        QDir::Files, QDirIterator::Subdirectories);
        if (!it.hasNext()) return false;
    }

    const bool hasVm = fileAt(base, "bin/server/jvm.dll")
                       || fileAt(base, "bin/client/jvm.dll")
                       || fileAt(base, "jre/bin/server/jvm.dll")
                       || fileAt(base, "jre/bin/client/jvm.dll")
                       || fileAt(base, "server/jvm.dll")
                       || fileAt(base, "client/jvm.dll");
    if (!hasVm) return false;

    // The class library image: lib/modules since Java 9, rt.jar on Java 8.
    return fileAt(base, "lib/modules")
           || fileAt(base, "modules")
           || fileAt(base, "jre/lib/rt.jar");
}
}

JavaInstaller::JavaInstaller(QObject *parent) : QObject(parent)
{
    m_nam = new QNetworkAccessManager(this);
}

JavaInstaller::~JavaInstaller()
{
    for (auto it = g_installsInFlight.begin(); it != g_installsInFlight.end();) {
        if (it.value() == this) {
            it = g_installsInFlight.erase(it);
        } else {
            ++it;
        }
    }
}

QString JavaInstaller::installRootFor(int majorVersion)
{
    return QDir(APPLICATION->root())
        .absoluteFilePath(QStringLiteral("java/temurin-%1").arg(majorVersion));
}

QString JavaInstaller::managedJavaFolder()
{
    return QDir(APPLICATION->root()).absoluteFilePath(QStringLiteral("java"));
}

QString JavaInstaller::javawPathFor(int majorVersion)
{
    return findJavawIn(installRootFor(majorVersion));
}

bool JavaInstaller::isUsableRuntime(const QString &javawPath)
{
    return isValidRuntime(javawPath);
}

bool JavaInstaller::isInstalled(int majorVersion)
{
    return isValidRuntime(javawPathFor(majorVersion));
}

void JavaInstaller::install(int majorVersion)
{
    if (m_busy) {
        emit finished(majorVersion, false, QString(),
                      tr("Une installation Java est déjà en cours."));
        return;
    }

    JavaInstaller *running = g_installsInFlight.value(majorVersion, nullptr);
    if (running && running != this) {
        // Somebody is already fetching this exact runtime: just follow it.
        m_busy = true;
        m_version = majorVersion;
        emit started(majorVersion);
        connect(running, &JavaInstaller::progress, this,
                [this](int major, qint64 received, qint64 total) {
                    if (major == m_version) emit progress(major, received, total);
                });
        connect(running, &JavaInstaller::finished, this,
                [this](int major, bool ok, const QString &javawPath, const QString &error) {
                    if (major != m_version || !m_busy) return;
                    m_busy = false;
                    emit finished(major, ok, javawPath, error);
                });
        connect(running, &QObject::destroyed, this, [this, majorVersion]() {
            if (m_busy && m_version == majorVersion) {
                m_busy = false;
                emit finished(majorVersion, false, QString(),
                              tr("Installation Java interrompue."));
            }
        });
        return;
    }

    m_busy = true;
    m_version = majorVersion;
    m_targetDir = installRootFor(majorVersion);
    m_stagingDir = m_targetDir + QStringLiteral(".installing");
    m_zipPath = m_targetDir + QStringLiteral(".zip");
    g_installsInFlight.insert(majorVersion, this);

    emit started(majorVersion);

    // Reuse an archive downloaded by an interrupted attempt instead of fetching
    // it all over again.
    if (QFile::exists(m_zipPath)) {
        if (!JlCompress::getFileList(m_zipPath).isEmpty()) {
            extractAndPublish();
            return;
        }
        QFile::remove(m_zipPath);
    }

    // Step 1: hit Adoptium with redirects following so the 302 lands on the
    // raw GitHub-hosted zip. QNetworkRequest follows redirects from Qt 5.6+
    // when explicitly enabled.
    QString url = QString(kAdoptiumApi).arg(majorVersion);
    QNetworkRequest req(url);
    req.setAttribute(QNetworkRequest::FollowRedirectsAttribute, true);
    req.setAttribute(QNetworkRequest::RedirectPolicyAttribute,
                     QNetworkRequest::NoLessSafeRedirectPolicy);
    req.setRawHeader("Accept", "application/octet-stream");
    req.setRawHeader("User-Agent", "BerserkMC/0.1 (JavaInstaller)");

    m_currentReply = m_nam->get(req);
    connect(m_currentReply, &QNetworkReply::finished,
            this, &JavaInstaller::onZipFinished);
    connect(m_currentReply, &QNetworkReply::downloadProgress,
            this, &JavaInstaller::onZipProgress);
}

void JavaInstaller::onMetaFinished()
{
    // unused for now — Adoptium /binary/latest returns the zip directly.
}

void JavaInstaller::onZipProgress(qint64 received, qint64 total)
{
    emit progress(m_version, received, total);
}

void JavaInstaller::onZipFinished()
{
    if (!m_currentReply) return;
    auto reply = m_currentReply;
    m_currentReply = nullptr;
    reply->deleteLater();

    if (reply->error() != QNetworkReply::NoError) {
        failWith(reply->errorString());
        return;
    }

    m_zipFile = new QFile(m_zipPath);
    if (!m_zipFile->open(QIODevice::WriteOnly)) {
        failWith(tr("Impossible d'écrire %1").arg(m_zipPath));
        return;
    }
    m_zipFile->write(reply->readAll());
    m_zipFile->close();
    delete m_zipFile;
    m_zipFile = nullptr;

    extractAndPublish();
}

void JavaInstaller::extractAndPublish()
{
    // Extract into a staging folder first: the live folder is only replaced
    // once the payload has been fully extracted and validated, so a crash or a
    // folder in use can never leave a half written runtime behind.
    FS::ensureFolderPathExists(m_stagingDir);
    QDir staging(m_stagingDir);
    staging.removeRecursively();
    FS::ensureFolderPathExists(m_stagingDir);

    QStringList extracted = JlCompress::extractDir(m_zipPath, m_stagingDir);
    if (extracted.isEmpty()) {
        discardStagedInstall();
        failWith(tr("Extraction du zip Temurin échouée."));
        return;
    }

    const QString stagedJavaw = findJavawIn(m_stagingDir);
    if (!isValidRuntime(stagedJavaw)) {
        discardStagedInstall();
        failWith(tr("L'installation Java est incomplète."));
        return;
    }

    QDir parent(m_targetDir);
    parent.cdUp();

    // Replace whatever was there before.
    QDir previous(m_targetDir);
    if (previous.exists() && !previous.removeRecursively()) {
        discardStagedInstall();
        failWith(tr("Le dossier Java existant est verrouillé. Fermez le jeu et réessayez."));
        return;
    }
    if (!parent.rename(QFileInfo(m_stagingDir).fileName(), QFileInfo(m_targetDir).fileName())) {
        discardStagedInstall();
        failWith(tr("Impossible de finaliser l'installation de Java."));
        return;
    }
    QFile::remove(m_zipPath);

    QString javaw = javawPathFor(m_version);
    if (!isValidRuntime(javaw)) {
        failWith(tr("javaw.exe introuvable après installation."));
        return;
    }

    // Optionally adopt the new javaw as the launcher's default if there's
    // none configured yet.
    if (APPLICATION->settings()->get("JavaPath").toString().isEmpty()) {
        APPLICATION->settings()->set("JavaPath", javaw);
    }

    finish(true, javaw, QString());
}

void JavaInstaller::discardStagedInstall()
{
    QDir(m_stagingDir).removeRecursively();
    QFile::remove(m_zipPath);
}

void JavaInstaller::finish(bool ok, const QString &javawPath, const QString &error)
{
    if (g_installsInFlight.value(m_version) == this) {
        g_installsInFlight.remove(m_version);
    }
    m_busy = false;
    if (!ok) {
        qWarning() << "Java" << m_version << "install failed:" << error;
    }
    emit finished(m_version, ok, javawPath, error);
}

void JavaInstaller::failWith(const QString &error)
{
    finish(false, QString(), error);
}

void JavaInstaller::cleanupReply(QNetworkReply* &reply)
{
    if (reply) {
        reply->abort();
        reply->deleteLater();
        reply = nullptr;
    }
}
