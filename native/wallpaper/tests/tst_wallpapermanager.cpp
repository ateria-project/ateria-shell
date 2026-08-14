#include "wallpapermanager.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QImage>
#include <QJsonDocument>
#include <QJsonObject>
#include <QTemporaryDir>
#include <QTest>
#include <QUrl>

#include <sys/stat.h>

namespace {

qint64 modifiedNanoseconds(const QString &path)
{
    struct stat metadata {};
    const QByteArray encodedPath = QFile::encodeName(path);
    if (::stat(encodedPath.constData(), &metadata) != 0)
        return 0;
    return static_cast<qint64>(metadata.st_mtim.tv_sec) * 1'000'000'000
        + static_cast<qint64>(metadata.st_mtim.tv_nsec);
}

void writeBytes(const QString &path, const QByteArray &contents)
{
    QFile file(path);
    QVERIFY(file.open(QIODevice::WriteOnly));
    QCOMPARE(file.write(contents), contents.size());
}

} // namespace

class WallpaperManagerTest : public QObject
{
    Q_OBJECT

private slots:
    void detectsSupportedMediaTypes();
    void preparesDisplaySizedImageCache();
    void deduplicatesKnownVideoSources();
    void preservesImageThatDoesNotNeedDownscaling();
    void adoptsCompatibleLegacyVideoCache();
};

void WallpaperManagerTest::detectsSupportedMediaTypes()
{
    QVERIFY(WallpaperManager::isVideo(QStringLiteral("file:///tmp/WALLPAPER.MP4")));
    QVERIFY(WallpaperManager::isVideo(QStringLiteral("/tmp/wallpaper.webm")));
    QVERIFY(!WallpaperManager::isVideo(QStringLiteral("/tmp/wallpaper.jpg")));
    QVERIFY(WallpaperManager::isImage(QStringLiteral("file:///tmp/wallpaper.webp")));
    QVERIFY(WallpaperManager::isLocalFile(QStringLiteral("file:///tmp/wallpaper.png")));
    QCOMPARE(WallpaperManager::localPath(QStringLiteral("file:///tmp/a%20wallpaper.png")),
             QStringLiteral("/tmp/a wallpaper.png"));
}

void WallpaperManagerTest::preparesDisplaySizedImageCache()
{
    QTemporaryDir directory;
    QVERIFY(directory.isValid());
    const QString sourcePath = directory.filePath(QStringLiteral("source.jpg"));
    QImage source(640, 400, QImage::Format_RGB32);
    source.fill(Qt::magenta);
    QVERIFY(source.save(sourcePath, "jpg"));

    WallpaperManager manager;
    manager.configure(directory.filePath(QStringLiteral("video")),
                      directory.filePath(QStringLiteral("images")));
    const QString sourceUrl = QUrl::fromLocalFile(sourcePath).toString();
    manager.prepareImage(sourceUrl, 320, 180);
    QTRY_VERIFY_WITH_TIMEOUT(!manager.imagePlaybackSource(sourceUrl).isEmpty(), 5000);

    const QString cachedPath = QUrl(manager.imagePlaybackSource(sourceUrl)).toLocalFile();
    QVERIFY(cachedPath != sourcePath);
    // PreserveAspectCrop needs enough pixels to cover both output axes.
    QCOMPARE(QImage(cachedPath).size(), QSize(320, 200));

    manager.prepareImage(sourceUrl, 320, 180);
    QTRY_COMPARE_WITH_TIMEOUT(QUrl(manager.imagePlaybackSource(sourceUrl)).toLocalFile(), cachedPath, 5000);
}

void WallpaperManagerTest::deduplicatesKnownVideoSources()
{
    QTemporaryDir directory;
    QVERIFY(directory.isValid());
    WallpaperManager manager;
    manager.configure(directory.filePath(QStringLiteral("video")),
                      directory.filePath(QStringLiteral("images")));

    const QString video = QUrl::fromLocalFile(directory.filePath(QStringLiteral("missing.mp4"))).toString();
    const QString image = QUrl::fromLocalFile(directory.filePath(QStringLiteral("image.jpg"))).toString();
    manager.reconcile({video, video, image}, 1920, 1080, video, false);
    QCOMPARE(manager.knownSources(), QStringList{video});
}

void WallpaperManagerTest::preservesImageThatDoesNotNeedDownscaling()
{
    QTemporaryDir directory;
    QVERIFY(directory.isValid());
    const QString sourcePath = directory.filePath(QStringLiteral("source.png"));
    QImage source(128, 72, QImage::Format_RGB32);
    source.fill(Qt::cyan);
    QVERIFY(source.save(sourcePath, "png"));

    WallpaperManager manager;
    manager.configure(directory.filePath(QStringLiteral("video")),
                      directory.filePath(QStringLiteral("images")));
    const QString sourceUrl = QUrl::fromLocalFile(sourcePath).toString();
    manager.prepareImage(sourceUrl, 320, 180);
    QTRY_VERIFY_WITH_TIMEOUT(!manager.imagePlaybackSource(sourceUrl).isEmpty(), 5000);
    QCOMPARE(QUrl(manager.imagePlaybackSource(sourceUrl)).toLocalFile(), sourcePath);
}

void WallpaperManagerTest::adoptsCompatibleLegacyVideoCache()
{
    QTemporaryDir directory;
    QVERIFY(directory.isValid());
    const QString cachePath = directory.filePath(QStringLiteral("video"));
    const QString thumbnailDirectory = QDir(cachePath).filePath(QStringLiteral("thumbnails"));
    QVERIFY(QDir().mkpath(thumbnailDirectory));

    const QString sourcePath = directory.filePath(QStringLiteral("source.mp4"));
    const QString legacyCachePath = QDir(cachePath).filePath(QStringLiteral("legacy-version.mp4"));
    const QString thumbnailPath = QDir(thumbnailDirectory).filePath(QStringLiteral("legacy.jpg"));
    writeBytes(sourcePath, QByteArrayLiteral("source fingerprint"));
    writeBytes(legacyCachePath, QByteArrayLiteral("previously encoded video"));
    writeBytes(thumbnailPath, QByteArrayLiteral("previous thumbnail"));

    const QFileInfo sourceInfo(sourcePath);
    const QFileInfo cacheInfo(legacyCachePath);
    const QJsonObject stored{{QStringLiteral("sourceSize"), sourceInfo.size()},
                             {QStringLiteral("sourceMtimeNs"), modifiedNanoseconds(sourcePath)},
                             {QStringLiteral("sourceWidth"), 640},
                             {QStringLiteral("sourceHeight"), 360},
                             {QStringLiteral("duration"), 1.0},
                             {QStringLiteral("sourceFrameRate"), QStringLiteral("24")},
                             {QStringLiteral("targetWidth"), 320},
                             {QStringLiteral("targetHeight"), 180},
                             {QStringLiteral("targetFrameRate"), QStringLiteral("24")},
                             {QStringLiteral("cachePath"), legacyCachePath},
                             {QStringLiteral("cacheSize"), cacheInfo.size()},
                             {QStringLiteral("cacheMtimeNs"), modifiedNanoseconds(legacyCachePath)},
                             {QStringLiteral("thumbnailPath"), thumbnailPath}};
    const QJsonObject manifest{{QStringLiteral("version"), 3},
                               {QStringLiteral("entries"),
                                QJsonObject{{sourcePath, stored}}}};
    writeBytes(QDir(cachePath).filePath(QStringLiteral("manifest.json")),
               QJsonDocument(manifest).toJson(QJsonDocument::Compact));

    WallpaperManager manager;
    manager.configure(cachePath, directory.filePath(QStringLiteral("images")));
    const QString sourceUrl = QUrl::fromLocalFile(sourcePath).toString();
    manager.reconcile({sourceUrl}, 320, 180, sourceUrl, false);
    manager.expeditePendingWork();
    QTRY_COMPARE_WITH_TIMEOUT(manager.entryFor(sourceUrl).value(QStringLiteral("status")).toString(),
                              QStringLiteral("ready"),
                              5000);
    QCOMPARE(QUrl(manager.playbackSource(sourceUrl)).toLocalFile(), legacyCachePath);
    QVERIFY(QFileInfo::exists(legacyCachePath));
}

QTEST_GUILESS_MAIN(WallpaperManagerTest)

#include "tst_wallpapermanager.moc"
