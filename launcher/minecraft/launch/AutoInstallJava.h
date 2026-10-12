// SPDX-License-Identifier: Apache-2.0
// Launch step: ensure the Java runtime required by the selected Minecraft
// version is actually available before the game starts. If the Java currently
// configured for the instance is missing, unreadable or too old, BerserkMC
// downloads the matching Adoptium Temurin JDK and activates it for this
// instance (JavaPath + OverrideJavaLocation), so the user never has to open the
// instance settings to pick a Java by hand.
//
// Runs *before* CheckJava so the freshly activated Java is the one validated
// and launched with.

#pragma once

#include <launch/LaunchStep.h>
#include <java/JavaChecker.h>

class JavaInstaller;

class AutoInstallJava : public LaunchStep
{
    Q_OBJECT

public:
    explicit AutoInstallJava(LaunchTask *parent) : LaunchStep(parent) {}
    ~AutoInstallJava() override = default;

    void executeTask() override;
    bool canAbort() const override
    {
        // A partially downloaded runtime has no meaningful "undo", and the
        // install is short enough that a clean failure message is friendlier
        // than an abortable half-state.
        return false;
    }

private slots:
    void onCheckFinished(JavaCheckResult result);
    void onInstallFinished(int major, bool ok, const QString &javawPath, const QString &error);

private:
    void startInstallOrAdopt();
    void adoptAndFinish(const QString &javawPath);

    int m_requiredMajor = 8;   // minimum Java major the Minecraft version needs
    int m_installMajor = 8;    // Temurin major we actually fetch (>= required)
    int m_lastReportedPercent = -1;
    JavaChecker *m_checker = nullptr;
    JavaInstaller *m_installer = nullptr;
};
