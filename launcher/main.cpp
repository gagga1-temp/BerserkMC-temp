#include "Application.h"

#include <QApplication>
#include <QQmlApplicationEngine>
#include <QQuickStyle>
#include <QFontDatabase>
#include <QDebug>
#include <QFile>
#include <QDir>
#include <QTextStream>
#include <QDateTime>
#include <qqml.h>

#include <cstring>

// #define BREAK_INFINITE_LOOP
// #define BREAK_EXCEPTION
// #define BREAK_RETURN

#ifdef BREAK_INFINITE_LOOP
#include <thread>
#include <chrono>
#endif

static int runQmlPreview(int argc, char *argv[])
{
    QApplication app(argc, argv);

    // Windows GUI subsystem swallows stdout/stderr — pipe Qt logs to a file so
    // we can debug without rebuilding as a console subsystem app.
    {
        QFile tmp(QDir::tempPath() + "/berserkmc-qml.log");
        tmp.open(QIODevice::WriteOnly | QIODevice::Truncate);
    }
    qInstallMessageHandler([](QtMsgType type, const QMessageLogContext &ctx, const QString &msg) {
        static QFile out(QDir::tempPath() + "/berserkmc-qml.log");
        if (!out.isOpen()) out.open(QIODevice::Append | QIODevice::Text);
        QTextStream ts(&out);
        ts << QDateTime::currentDateTime().toString(Qt::ISODateWithMs)
           << " [" << type << "] " << msg
           << " (" << (ctx.file ? ctx.file : "?") << ":" << ctx.line << ")\n";
        out.flush();
    });

    Q_INIT_RESOURCE(qml);
    Q_INIT_RESOURCE(logo);

    QQuickStyle::setStyle("Basic");

    // Bundled fonts: load them upfront so QML can reference by family name.
    QFontDatabase::addApplicationFont(":/qml/fonts/DMSans.ttf");
    QFontDatabase::addApplicationFont(":/qml/fonts/Caveat-Bold.ttf");
    QFontDatabase::addApplicationFont(":/qml/fonts/VT323-Regular.ttf");

    // Register the Theme singleton directly so we don't depend on qmldir module
    // path resolution.
    qmlRegisterSingletonType(QUrl(QStringLiteral("qrc:/qml/Theme.qml")),
                             "BerserkMC.Ui", 1, 0, "Theme");

    QQmlApplicationEngine engine;
    engine.load(QUrl(QStringLiteral("qrc:/qml/Main.qml")));
    if (engine.rootObjects().isEmpty()) {
        qCritical() << "QML root failed to load — see warnings above.";
        return 1;
    }
    return app.exec();
}

int main(int argc, char *argv[])
{
#ifdef BREAK_INFINITE_LOOP
    while(true)
    {
        std::this_thread::sleep_for(std::chrono::milliseconds(250));
    }
#endif
#ifdef BREAK_EXCEPTION
    throw 42;
#endif
#ifdef BREAK_RETURN
    return 42;
#endif

#if (QT_VERSION >= QT_VERSION_CHECK(5, 6, 0))
    QApplication::setAttribute(Qt::AA_EnableHighDpiScaling);
    QGuiApplication::setAttribute(Qt::AA_UseHighDpiPixmaps);
#endif

    // Early opt-in to the QML preview shell. We scan argv before constructing
    // the full Application to avoid the Widgets bootstrap when we just want to
    // iterate on the new UI.
    for (int i = 1; i < argc; ++i) {
        if (std::strcmp(argv[i], "--qml-preview") == 0) {
            return runQmlPreview(argc, argv);
        }
    }

    // initialize Qt
    Application app(argc, argv);

    switch (app.status())
    {
    case Application::StartingUp:
    case Application::Initialized:
    {
        Q_INIT_RESOURCE(multimc);
        Q_INIT_RESOURCE(backgrounds);
        Q_INIT_RESOURCE(documents);
        Q_INIT_RESOURCE(logo);

        Q_INIT_RESOURCE(pe_dark);
        Q_INIT_RESOURCE(pe_light);
        Q_INIT_RESOURCE(pe_blue);
        Q_INIT_RESOURCE(pe_colored);
        Q_INIT_RESOURCE(OSX);
        Q_INIT_RESOURCE(iOS);
        Q_INIT_RESOURCE(flat);

        Q_INIT_RESOURCE(skins);
        Q_INIT_RESOURCE(qml);
        return app.exec();
    }
    case Application::Failed:
        return 1;
    case Application::Succeeded:
        return 0;
    }
}
