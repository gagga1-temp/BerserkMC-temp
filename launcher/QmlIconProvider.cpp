// SPDX-License-Identifier: Apache-2.0
#include "QmlIconProvider.h"

#include "Application.h"
#include "icons/IconList.h"

#include <QImage>
#include <QPixmap>
#include <QIcon>

QmlIconProvider::QmlIconProvider()
    : QQuickImageProvider(QQuickImageProvider::Image)
{
}

QImage QmlIconProvider::requestImage(const QString &id, QSize *size, const QSize &requestedSize)
{
    QSize target = requestedSize.isValid() && !requestedSize.isEmpty()
                       ? requestedSize
                       : QSize(128, 128);

    auto icons = APPLICATION ? APPLICATION->icons() : nullptr;
    QIcon icon;
    if (icons) {
        icon = icons->getIcon(id);
    }

    QPixmap pix;
    if (!icon.isNull()) {
        pix = icon.pixmap(target);
    }
    if (pix.isNull() && icons) {
        // Fall back to the launcher's default Minecraft icon.
        icon = icons->getIcon(QStringLiteral("default"));
        if (!icon.isNull()) pix = icon.pixmap(target);
    }
    if (pix.isNull()) {
        // Last-resort: a transparent placeholder so QML still has a valid image.
        QImage placeholder(target, QImage::Format_ARGB32_Premultiplied);
        placeholder.fill(Qt::transparent);
        if (size) *size = target;
        return placeholder;
    }

    if (size) *size = pix.size();
    return pix.toImage();
}
