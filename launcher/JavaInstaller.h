// SPDX-License-Identifier: Apache-2.0
// One-shot auto-installer for Adoptium Temurin JDKs. Downloads a Temurin zip
// for the requested major version and extracts it to
//     <launcher root>/java/temurin-<version>/
// then surfaces the new javaw.exe path. Designed to be driven from QML via
// QmlBridge.

#pragma once

#include <QObject>
#include <QString>
#include <QNetworkReply>

class QNetworkAccessManager;
class QFile;

class JavaInstaller : public QObject
{
    Q_OBJECT
public:
    explicit JavaInstaller(QObject *parent = nullptr);

    // Trigger a fresh install of Temurin major version (8, 11, 17, 21, 23).
    // Cancels any in-flight job.
    void install(int majorVersion);

    bool isBusy() const { return m_busy; }

    // Returns the install root for a given major version (regardless of
    // whether it's actually present).
    static QString installRootFor(int majorVersion);

    // True if javaw.exe already exists under installRootFor(majorVersion).
    static bool isInstalled(int majorVersion);

    // Returns the absolute path to javaw.exe for the installed major version,
    // or an empty string when not installed.
    static QString javawPathFor(int majorVersion);

signals:
    void progress(int majorVersion, qint64 bytesReceived, qint64 bytesTotal);
    void started(int majorVersion);
    void finished(int majorVersion, bool ok, const QString &javawPath, const QString &error);

private slots:
    void onMetaFinished();
    void onZipFinished();
    void onZipProgress(qint64 received, qint64 total);

private:
    void cleanupReply(QNetworkReply* &reply);
    void failWith(const QString &error);
    void extractAndPublish();

    QNetworkAccessManager *m_nam = nullptr;
    int m_version = 0;
    QString m_zipPath;            // local temp .zip file
    QString m_targetDir;          // <root>/java/temurin-<version>/
    bool m_busy = false;
    QNetworkReply *m_currentReply = nullptr;
    QFile *m_zipFile = nullptr;
};
