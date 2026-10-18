// SPDX-License-Identifier: Apache-2.0
#include "AutoInstallJava.h"

#include <launch/LaunchTask.h>
#include <minecraft/MinecraftInstance.h>
#include <minecraft/PackProfile.h>
#include <minecraft/VersionFilterData.h>

#include "JavaInstaller.h"
#include "FileSystem.h"

#include <QDir>
#include <QDateTime>
#include <QDebug>

namespace {
// Translate the Minecraft version's release date into the minimum Java major it
// needs. Mirrors VerifyJavaInstall's thresholds so that the install step and the
// verification step never disagree about what "too old" means.
int requiredJavaMajor(const QDateTime &releaseDate)
{
    if (releaseDate >= g_VersionFilterData.java21BeginsDate) return 21;
    if (releaseDate >= g_VersionFilterData.java17BeginsDate) return 17;
    if (releaseDate >= g_VersionFilterData.java16BeginsDate) return 16;
    return 8;
}

// Adoptium no longer publishes a GA build for Java 16 (a short-lived, non-LTS
// release). Java 17 runs the whole 1.17.x line, so fetch that instead.
int adoptiumMajorFor(int required)
{
    return required == 16 ? 17 : required;
}
}

void AutoInstallJava::executeTask()
{
    auto instance = std::dynamic_pointer_cast<MinecraftInstance>(m_parent->instance());
    if (!instance) {
        emitSucceeded();
        return;
    }

    auto profile = instance->getPackProfile();
    auto mcComponent = profile ? profile->getComponent("net.minecraft") : nullptr;
    if (!mcComponent) {
        // Should not happen: this step runs after the profile has been resolved.
        qWarning() << "AutoInstallJava: net.minecraft component is not available; "
                      "skipping the Java check and leaving the configured runtime as-is.";
        emitSucceeded();
        return;
    }

    m_requiredMajor = requiredJavaMajor(mcComponent->getReleaseDateTime());
    m_installMajor = adoptiumMajorFor(m_requiredMajor);

    auto settings = instance->settings();
    QString configuredPath = FS::ResolveExecutable(settings->get("JavaPath").toString());

    if (configuredPath.isEmpty()) {
        emit logLine(tr("No usable Java is configured for this instance."), MessageLevel::Launcher);
        startInstallOrAdopt();
        return;
    }

    // Never launch a runtime we installed ourselves when its payload is
    // incomplete: it can only pop up an error dialog and stall the check.
    const QString managedRoot = JavaInstaller::managedJavaFolder() + QLatin1Char('/');
    if (configuredPath.startsWith(managedRoot, Qt::CaseInsensitive)
        && !JavaInstaller::isUsableRuntime(configuredPath)) {
        emit logLine(tr("The installed Java %1 runtime is incomplete; it will be installed again.")
                         .arg(m_installMajor),
                     MessageLevel::Warning);
        startInstallOrAdopt();
        return;
    }

    emit logLine(tr("Checking the configured Java against the Java %1 requirement...")
                     .arg(m_requiredMajor),
                 MessageLevel::Launcher);

    m_checker = new JavaChecker(this);
    m_checker->m_path = configuredPath;
    connect(m_checker, &JavaChecker::checkFinished, this, &AutoInstallJava::onCheckFinished);
    m_checker->performCheck();
}

void AutoInstallJava::onCheckFinished(JavaCheckResult result)
{
    if (result.validity == JavaCheckResult::Validity::Valid &&
        result.javaVersion.major() >= m_requiredMajor) {
        emit logLine(tr("The configured Java (%1) already meets the requirement.")
                         .arg(result.javaVersion.toString()),
                     MessageLevel::Launcher);
        emitSucceeded();
        return;
    }

    if (result.validity == JavaCheckResult::Validity::Valid) {
        emit logLine(tr("The configured Java is %1, but this Minecraft version needs Java %2 or newer.")
                         .arg(result.javaVersion.toString())
                         .arg(m_requiredMajor),
                     MessageLevel::Warning);
    } else {
        emit logLine(tr("The configured Java could not be used; a suitable runtime will be installed."),
                     MessageLevel::Warning);
    }
    startInstallOrAdopt();
}

void AutoInstallJava::startInstallOrAdopt()
{
    // Reuse a previously downloaded runtime when it is already on disk.
    if (JavaInstaller::isInstalled(m_installMajor)) {
        adoptAndFinish(JavaInstaller::javawPathFor(m_installMajor));
        return;
    }

    emit logLine(tr("Downloading Java %1 (Adoptium Temurin) — this only happens once...")
                     .arg(m_installMajor),
                 MessageLevel::Launcher);

    m_installer = new JavaInstaller(this);
    connect(m_installer, &JavaInstaller::progress, this,
            [this](int major, qint64 received, qint64 total) {
                if (total <= 0) {
                    return;
                }
                const int percent = int((received * 100) / total);
                // Log at 25% milestones to keep the console readable.
                if (percent / 25 != m_lastReportedPercent / 25) {
                    m_lastReportedPercent = percent;
                    emit logLine(tr("Java %1 download: %2%").arg(major).arg(percent),
                                 MessageLevel::Launcher);
                }
            });
    connect(m_installer, &JavaInstaller::finished, this, &AutoInstallJava::onInstallFinished);
    m_installer->install(m_installMajor);
}

void AutoInstallJava::onInstallFinished(int major, bool ok, const QString &javawPath, const QString &error)
{
    if (!ok) {
        emit logLine(tr("Automatic Java %1 installation failed: %2").arg(major).arg(error),
                     MessageLevel::Error);
        emitFailed(tr("Could not install Java %1 automatically. Install a Java %1 runtime, or set "
                      "one manually in the instance settings, then try again.")
                       .arg(major));
        return;
    }
    adoptAndFinish(javawPath);
}

void AutoInstallJava::adoptAndFinish(const QString &javawPath)
{
    auto instance = std::dynamic_pointer_cast<MinecraftInstance>(m_parent->instance());
    if (!instance || javawPath.isEmpty()) {
        emitFailed(tr("Java was installed but its executable could not be located."));
        return;
    }

    auto settings = instance->settings();
    settings->set("OverrideJavaLocation", true);
    settings->set("JavaPath", QDir::toNativeSeparators(javawPath));

    emit logLine(tr("Java %1 activated for this instance:\n%2\n").arg(m_requiredMajor).arg(javawPath),
                 MessageLevel::Launcher);
    emitSucceeded();
}
