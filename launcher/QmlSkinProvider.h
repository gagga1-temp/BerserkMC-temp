// SPDX-License-Identifier: Apache-2.0
// QQuickImageProvider for Minecraft skins / faces so QML can do:
//     Image { source: "image://skins/face/Steve/classic" }
//     Image { source: "image://skins/list/Alex" }
//     Image { source: "image://skins/account/<internalId>" }
//
// The library itself lives in SkinsModel; account skins are rendered from the
// PNG bytes stored on the account (so they survive a library cleanup).

#pragma once

#include <QQuickImageProvider>
#include <QImage>

class QmlSkinProvider : public QQuickImageProvider
{
public:
    QmlSkinProvider();
    QImage requestImage(const QString &id, QSize *size, const QSize &requestedSize) override;
};
