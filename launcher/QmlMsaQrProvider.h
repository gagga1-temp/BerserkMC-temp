// SPDX-License-Identifier: Apache-2.0
// QQuickImageProvider for the Microsoft sign-in QR code:
//     Image { source: App.msaQrImageSource("https://microsoft.com/link?otc=…") }
// The id is the hex encoding of the UTF-8 payload (see
// QmlBridge::msaQrImageSource), so it reaches us untouched by URL parsing.

#pragma once

#include <QQuickImageProvider>
#include <QImage>

class QmlMsaQrProvider : public QQuickImageProvider
{
public:
    QmlMsaQrProvider();
    QImage requestImage(const QString &id, QSize *size, const QSize &requestedSize) override;
};
