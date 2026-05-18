// SPDX-License-Identifier: Apache-2.0
// QQuickImageProvider that resolves MultiMC instance icon keys (including the
// user's custom icons in icons/) to QImage so QML can do:
//     Image { source: "image://mmcicon/<key>" }
//
// Falls back to the bundled "minecraft" grass-block icon when the key is
// unknown or empty so we never paint nothing.

#pragma once

#include <QQuickImageProvider>
#include <QImage>

class QmlIconProvider : public QQuickImageProvider
{
public:
    QmlIconProvider();
    QImage requestImage(const QString &id, QSize *size, const QSize &requestedSize) override;
};
