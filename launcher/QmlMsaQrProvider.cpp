// SPDX-License-Identifier: Apache-2.0
#include "QmlMsaQrProvider.h"

#include <qrcode/QrCodeGenerator.h>

QmlMsaQrProvider::QmlMsaQrProvider()
    : QQuickImageProvider(QQuickImageProvider::Image)
{
}

QImage QmlMsaQrProvider::requestImage(const QString &id, QSize *size, const QSize &requestedSize)
{
    // requestImage may run off the GUI thread — QImage only, no QPixmap.
    const QString text = QString::fromUtf8(QByteArray::fromHex(id.toLatin1()));

    QImage image = text.isEmpty() ? QImage(320, 320, QImage::Format_ARGB32)
                                  : qrcode::generateQr(text, 320, 4);
    if (image.isNull()) {
        image = QImage(320, 320, QImage::Format_ARGB32);
        image.fill(Qt::transparent);
    }
    if (requestedSize.isValid() && !requestedSize.isEmpty()) {
        image = image.scaled(requestedSize, Qt::KeepAspectRatio, Qt::SmoothTransformation);
    }
    if (size) *size = image.size();
    return image;
}
