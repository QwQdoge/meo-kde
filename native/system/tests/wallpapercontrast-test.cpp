#include "wallpapercontrast.h"

#include <QImage>
#include <QPainter>
#include <QTest>

class WallpaperContrastTest : public QObject
{
    Q_OBJECT

private:
    // Left half black, right half white.
    static QImage splitImage(int width, int height)
    {
        QImage image(width, height, QImage::Format_RGB32);
        image.fill(Qt::black);
        QPainter painter(&image);
        painter.fillRect(QRect(width / 2, 0, width - width / 2, height), Qt::white);
        return image;
    }

private slots:
    void mixedWallpaperGivesDifferentAnswersPerRegion()
    {
        const QImage image = splitImage(400, 200);
        const QSizeF screen(1600, 800);
        const qreal left = WallpaperContrast::regionLuminance(image, QRectF(0, 0, 400, 40), screen);
        const qreal right = WallpaperContrast::regionLuminance(image, QRectF(1200, 0, 400, 40), screen);
        QVERIFY(left >= 0 && left < WallpaperContrast::kDarkForegroundThreshold);
        QVERIFY(right > WallpaperContrast::kDarkForegroundThreshold);
        QVERIFY(right > 0.9);
    }

    void cropFollowsPreserveAspectFill()
    {
        // A 2:1 image on a 1:1 screen shows only its central half, so the
        // black/white boundary (at the image centre) lands at the screen centre.
        const QImage image = splitImage(400, 200);
        const QSizeF screen(800, 800);
        const qreal left = WallpaperContrast::regionLuminance(image, QRectF(0, 0, 300, 800), screen);
        const qreal right = WallpaperContrast::regionLuminance(image, QRectF(500, 0, 300, 800), screen);
        QVERIFY(left < 0.05);
        QVERIFY(right > 0.95);
    }

    void unusableInputIsUnknownNotGuessed()
    {
        QCOMPARE(WallpaperContrast::regionLuminance(QImage(), QRectF(0, 0, 10, 10), QSizeF(100, 100)), -1.0);
        const QImage image = splitImage(40, 20);
        QCOMPARE(WallpaperContrast::regionLuminance(image, QRectF(0, 0, 0, 10), QSizeF(100, 100)), -1.0);
        QCOMPARE(WallpaperContrast::regionLuminance(image, QRectF(500, 500, 10, 10), QSizeF(100, 100)), -1.0);
    }

    void queryWithoutWallpaperFallsBack()
    {
        WallpaperContrast contrast;
        QCOMPARE(contrast.luminance(0, 0, 10, 10, 100, 100, QStringLiteral("/nonexistent.png")), -1.0);
        QVERIFY(contrast.prefersDarkForeground(0, 0, 10, 10, 100, 100, true,
                                               QStringLiteral("/nonexistent.png")));
        QVERIFY(!contrast.prefersDarkForeground(0, 0, 10, 10, 100, 100, false,
                                                QStringLiteral("/nonexistent.png")));
    }
};

QTEST_MAIN(WallpaperContrastTest)
#include "wallpapercontrast-test.moc"
