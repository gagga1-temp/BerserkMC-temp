// SPDX-License-Identifier: Apache-2.0
#include "QmlIconProvider.h"

#include "Application.h"
#include "icons/IconList.h"

#include <QImage>
#include <QPainter>
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

    // Render straight into a QImage: requestImage may run off the GUI thread,
    // and QPixmap is not safe outside the GUI thread. Painting via QIcon keeps
    // any native scaling without touching QPixmap.
    QImage img(target, QImage::Format_ARGB32_Premultiplied);
    img.fill(Qt::transparent);

    auto icons = APPLICATION ? APPLICATION->icons() : nullptr;
    QIcon icon;
    if (icons) {
        icon = icons->getIcon(id);
    }
    if (icon.isNull() && icons) {
        // Fall back to the launcher's default Minecraft icon.
        icon = icons->getIcon(QStringLiteral("default"));
    }
    if (!icon.isNull()) {
        QPainter p(&img);
        img.fill(Qt::transparent);
        icon.paint(&p, QRect(QPoint(0, 0), target));
    }

    if (size) *size = target;
    return img;
}
