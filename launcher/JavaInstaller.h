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
    ~JavaInstaller() override;

    // Trigger a fresh install of Temurin major version (8, 11, 17, 21, 23).
    // A second call for a version that is already being installed just follows
    // that install instead of starting a competing one.
    void install(int majorVersion);

    bool isBusy() const { return m_busy; }

    // Returns the install root for a given major version (regardless of
    // whether it's actually present).
    static QString installRootFor(int majorVersion);

    // Folder holding every runtime managed by the launcher.
    static QString managedJavaFolder();

    // True when a complete runtime is already installed for that version.
    static bool isInstalled(int majorVersion);

    // Returns the absolute path to javaw.exe for the installed major version,
    // or an empty string when not installed.
    static QString javawPathFor(int majorVersion);

    // True when the runtime at the given path is complete and usable. A half
    // extracted folder has a javaw.exe but cannot start the JVM at all.
    static bool isUsableRuntime(const QString &javawPath);

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
    void finish(bool ok, const QString &javawPath, const QString &error);
    void discardStagedInstall();
    void extractAndPublish();

    QNetworkAccessManager *m_nam = nullptr;
    int m_version = 0;
    QString m_zipPath;            // local temp .zip file
    QString m_targetDir;          // <root>/java/temurin-<version>/
    QString m_stagingDir;         // <root>/java/temurin-<version>.installing/
    bool m_busy = false;
    QNetworkReply *m_currentReply = nullptr;
    QFile *m_zipFile = nullptr;
};
