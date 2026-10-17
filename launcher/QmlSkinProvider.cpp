// SPDX-License-Identifier: Apache-2.0
#include "QmlSkinProvider.h"

#include "Application.h"
#include "minecraft/auth/AccountList.h"
#include "minecraft/auth/MinecraftAccount.h"
#include "skins/SkinTypes.h"
#include "skins/SkinUtils.h"
#include "skins/SkinsModel.h"
#include "skins/TextureMappings.h"

#include <QPainter>
#include <QUrl>

namespace {

QImage transparentImage(int target)
{
    QImage img(target, target, QImage::Format_ARGB32_Premultiplied);
    img.fill(Qt::transparent);
    return img;
}

// Render the front of the head (face) + hat overlay, like MinecraftAccount::getFace()
QImage renderHead(const QImage &texture, int target)
{
    if (texture.isNull() || texture.width() < 64 || texture.height() < 32) {
        return QImage();
    }

    QImage out = transparentImage(target);
    QPainter painter(&out);

    const auto &face = Skins::head.front;
    const auto &cover = Skins::head_cover.front;

    // Black base so transparent skins still read as a head silhouette.
    painter.fillRect(0, 0, target, target, Qt::black);
    painter.drawImage(QRect(0, 0, target, target),
                      texture.copy(int(face.x), int(face.y), int(face.w), int(face.h)));
    painter.drawImage(QRect(0, 0, target, target),
                      texture.copy(int(cover.x), int(cover.y), int(cover.w), int(cover.h)));
    painter.end();
    return out;
}

QImage scaleTo(const QImage &src, int target)
{
    if (src.isNull()) {
        return QImage();
    }
    if (src.width() == target && src.height() == target) {
        return src;
    }
    return src.scaled(target, target, Qt::IgnoreAspectRatio, Qt::FastTransformation);
}

Skins::Model modelFromVariant(const QString &variant)
{
    return (variant == QLatin1String("slim")) ? Skins::Model::Slim : Skins::Model::Classic;
}

} // namespace

QmlSkinProvider::QmlSkinProvider()
    : QQuickImageProvider(QQuickImageProvider::Image)
{
}

QImage QmlSkinProvider::requestImage(const QString &id, QSize *size, const QSize &requestedSize)
{
    int target = 72;
    if (requestedSize.isValid() && !requestedSize.isEmpty()) {
        target = qMax(requestedSize.width(), requestedSize.height());
    }
    if (target < 8) {
        target = 8;
    }

    // id forms: <kind>/<key>[/<variant>]  (a trailing ?query is ignored, QML may
    // append one to bust the image cache after a skin change)
    QString cleanId = id;
    const int queryAt = cleanId.indexOf(QLatin1Char('?'));
    if (queryAt >= 0) {
        cleanId = cleanId.left(queryAt);
    }
    const QStringList parts = cleanId.split(QLatin1Char('/'));
    const QString kind = parts.value(0);
    const QString key = parts.size() > 1
                            ? QUrl::fromPercentEncoding(parts.at(1).toUtf8())
                            : QString();
    const QString variant = parts.size() > 2 ? parts.at(2).toLower() : QString();

    QImage result;
    auto skins = APPLICATION ? APPLICATION->skinsModel() : nullptr;

    if (skins) {
        if (kind == QLatin1String("list")) {
            const auto &entry = skins->skinEntry(key);
            if (!entry.isNull()) {
                result = scaleTo(entry.getListTexture(), target);
            }
        } else if (kind == QLatin1String("face")) {
            const auto &entry = skins->skinEntry(key);
            if (!entry.isNull()) {
                result = renderHead(entry.getTextureFor(modelFromVariant(variant)), target);
            }
        } else if (kind == QLatin1String("account")) {
            auto accounts = APPLICATION->accounts();
            if (accounts) {
                MinecraftAccountPtr account;
                int index = -1;
                if (accounts->getAccountById(key, account, index) && account) {
                    QImage texture;
                    QString textureId;
                    if (Skins::readSkinFromData(account->getSkin(), texture, textureId)) {
                        result = renderHead(texture, target);
                    }
                }
            }
        }
    }

    if (result.isNull()) {
        result = transparentImage(target);
    }
    if (size) {
        *size = result.size();
    }
    return result;
}
