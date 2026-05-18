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
}

JavaInstaller::JavaInstaller(QObject *parent) : QObject(parent)
{
    m_nam = new QNetworkAccessManager(this);
}

QString JavaInstaller::installRootFor(int majorVersion)
{
    return QDir(APPLICATION->root())
        .absoluteFilePath(QStringLiteral("java/temurin-%1").arg(majorVersion));
}

QString JavaInstaller::javawPathFor(int majorVersion)
{
    QDir base(installRootFor(majorVersion));
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

bool JavaInstaller::isInstalled(int majorVersion)
{
    return !javawPathFor(majorVersion).isEmpty();
}

void JavaInstaller::install(int majorVersion)
{
    if (m_busy) {
        emit finished(majorVersion, false, QString(),
                      tr("Une installation Java est déjà en cours."));
        return;
    }
    m_busy = true;
    m_version = majorVersion;
    m_targetDir = installRootFor(majorVersion);

    emit started(majorVersion);

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

    // Make sure target dir exists and is empty.
    FS::ensureFolderPathExists(m_targetDir);
    QDir td(m_targetDir);
    td.removeRecursively();
    FS::ensureFolderPathExists(m_targetDir);

    m_zipPath = QDir(m_targetDir).filePath("temurin.zip");
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
    QStringList extracted = JlCompress::extractDir(m_zipPath, m_targetDir);
    if (extracted.isEmpty()) {
        failWith(tr("Extraction du zip Temurin échouée."));
        return;
    }

    QFile::remove(m_zipPath);

    QString javaw = javawPathFor(m_version);
    if (javaw.isEmpty()) {
        failWith(tr("javaw.exe introuvable après extraction."));
        return;
    }

    // Optionally adopt the new javaw as the launcher's default if there's
    // none configured yet.
    if (APPLICATION->settings()->get("JavaPath").toString().isEmpty()) {
        APPLICATION->settings()->set("JavaPath", javaw);
    }

    m_busy = false;
    emit finished(m_version, true, javaw, QString());
}

void JavaInstaller::failWith(const QString &error)
{
    m_busy = false;
    emit finished(m_version, false, QString(), error);
}

void JavaInstaller::cleanupReply(QNetworkReply* &reply)
{
    if (reply) {
        reply->abort();
        reply->deleteLater();
        reply = nullptr;
    }
}
