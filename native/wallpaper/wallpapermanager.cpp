#include "wallpapermanager.h"
#include "processscheduler.h"

#include <QCoreApplication>
#include <QCryptographicHash>
#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QFutureWatcher>
#include <QImage>
#include <QImageReader>
#include <QImageWriter>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QProcess>
#include <QSaveFile>
#include <QSet>
#include <QStandardPaths>
#include <QTimer>
#include <QUrl>
#include <QtConcurrentRun>

#include <algorithm>
#include <cstdio>
#include <cmath>
#include <functional>
#include <numeric>
#include <optional>

#include <sys/stat.h>

namespace {

constexpr int ManifestVersion = 1;
constexpr int VideoCacheVersion = 1;
constexpr int ImageCacheVersion = 1;
constexpr int ThumbnailVersion = 1;
constexpr int ThumbnailWidth = 640;
constexpr int ImageCacheLimit = 8;
constexpr double MaximumFrameRate = 30.0;

QString fileUrl(const QString &path)
{
    return QUrl::fromLocalFile(path).toString(QUrl::FullyEncoded);
}

bool isNonemptyFile(const QString &path)
{
    const QFileInfo info(path);
    return info.isFile() && info.size() > 0;
}

bool replaceFile(const QString &source, const QString &destination)
{
    const QByteArray encodedSource = QFile::encodeName(source);
    const QByteArray encodedDestination = QFile::encodeName(destination);
    return ::rename(encodedSource.constData(), encodedDestination.constData()) == 0;
}

qint64 jsonInteger(const QJsonObject &object, const QString &key)
{
    return object.value(key).toVariant().toLongLong();
}

qint64 modifiedNanoseconds(const QString &path)
{
    struct stat metadata {};
    const QByteArray encodedPath = QFile::encodeName(path);
    if (::stat(encodedPath.constData(), &metadata) != 0)
        return 0;
    return static_cast<qint64>(metadata.st_mtim.tv_sec) * 1'000'000'000
        + static_cast<qint64>(metadata.st_mtim.tv_nsec);
}

double frameRateValue(const QString &text)
{
    const QStringList parts = text.split(u'/');
    bool numeratorOk = false;
    bool denominatorOk = true;
    const double numerator = parts.value(0).toDouble(&numeratorOk);
    const double denominator = parts.size() > 1 ? parts.value(1).toDouble(&denominatorOk) : 1.0;
    if (!numeratorOk || !denominatorOk || numerator <= 0.0 || denominator <= 0.0)
        return 0.0;
    return numerator / denominator;
}

QString canonicalFrameRate(const QString &text)
{
    const QStringList parts = text.split(u'/');
    bool numeratorOk = false;
    bool denominatorOk = true;
    qint64 numerator = parts.value(0).toLongLong(&numeratorOk);
    qint64 denominator = parts.size() > 1 ? parts.value(1).toLongLong(&denominatorOk) : 1;
    if (!numeratorOk || !denominatorOk || numerator <= 0 || denominator <= 0)
        return {};
    const qint64 divisor = std::gcd(numerator, denominator);
    numerator /= divisor;
    denominator /= divisor;
    return denominator == 1 ? QString::number(numerator)
                            : QStringLiteral("%1/%2").arg(numerator).arg(denominator);
}

QString normalizedFrameRate(const QString &primary, const QString &fallback = {})
{
    if (frameRateValue(primary) > 0.0)
        return canonicalFrameRate(primary);
    if (frameRateValue(fallback) > 0.0)
        return canonicalFrameRate(fallback);
    return {};
}

QSize targetDimensions(int width, int height, int maximumWidth, int maximumHeight, bool even)
{
    if (width < 1 || height < 1)
        return {};

    const double scale = std::min(1.0,
                                  std::max(static_cast<double>(maximumWidth) / width,
                                           static_cast<double>(maximumHeight) / height));
    if (even) {
        return {std::max(2, static_cast<int>(width * scale) / 2 * 2),
                std::max(2, static_cast<int>(height * scale) / 2 * 2)};
    }
    return {std::max(1, static_cast<int>(std::ceil(width * scale))),
            std::max(1, static_cast<int>(std::ceil(height * scale)))};
}

QString digest(const QStringList &fields)
{
    QCryptographicHash hash(QCryptographicHash::Sha256);
    for (qsizetype index = 0; index < fields.size(); ++index) {
        if (index > 0)
            hash.addData(QByteArrayView("\0", 1));
        hash.addData(fields.at(index).toUtf8());
    }
    return QString::fromLatin1(hash.result().toHex());
}

QString videoIdentity(const QString &path,
                      qint64 size,
                      qint64 modified,
                      int width,
                      int height,
                      const QString &frameRate)
{
    return digest({path,
                   QString::number(size),
                   QString::number(modified),
                   QString::number(width),
                   QString::number(height),
                   frameRate,
                   QString::number(VideoCacheVersion)});
}

QString imageIdentity(const QString &path, qint64 size, qint64 modified, int width, int height)
{
    return digest({path,
                   QString::number(size),
                   QString::number(modified),
                   QString::number(width),
                   QString::number(height),
                   QString::number(ImageCacheVersion)});
}

QString thumbnailIdentity(const QString &path, qint64 size, qint64 modified)
{
    return digest({path,
                   QString::number(size),
                   QString::number(modified),
                   QString::number(ThumbnailWidth),
                   QString::number(ThumbnailVersion)});
}

void removeMatchingFiles(const QString &directory, const QStringList &filters)
{
    QDir dir(directory);
    const QFileInfoList files = dir.entryInfoList(filters, QDir::Files | QDir::NoSymLinks);
    for (const QFileInfo &file : files)
        QFile::remove(file.absoluteFilePath());
}

void cleanupImageCache(const QString &cachePath, const QString &retainedPath)
{
    QDir dir(cachePath);
    removeMatchingFiles(cachePath, {QStringLiteral("*.partial.*")});
    QFileInfoList files = dir.entryInfoList({QStringLiteral("*.png")},
                                            QDir::Files | QDir::NoSymLinks,
                                            QDir::Time);
    if (!retainedPath.isEmpty()) {
        const auto retained = std::find_if(files.begin(), files.end(), [&](const QFileInfo &file) {
            return file.absoluteFilePath() == retainedPath;
        });
        if (retained != files.end())
            std::rotate(files.begin(), retained, retained + 1);
    }
    for (qsizetype index = ImageCacheLimit; index < files.size(); ++index)
        QFile::remove(files.at(index).absoluteFilePath());
}

QVariantMap prepareImageCache(const QString &source,
                              const QString &cachePath,
                              int maximumWidth,
                              int maximumHeight)
{
    QVariantMap result;
    const QFileInfo sourceInfo(source);
    if (!sourceInfo.isFile()) {
        result.insert(QStringLiteral("error"),
                      QCoreApplication::translate("WallpaperManager", "The wallpaper image no longer exists."));
        return result;
    }

    QImageReader metadataReader(source);
    metadataReader.setAutoTransform(true);
    QSize sourceSize = metadataReader.size();
    if (!sourceSize.isValid()) {
        result.insert(QStringLiteral("error"), metadataReader.errorString());
        return result;
    }

    const auto transformation = metadataReader.transformation();
    const bool rotated = transformation == QImageIOHandler::TransformationRotate90
        || transformation == QImageIOHandler::TransformationRotate270
        || transformation == QImageIOHandler::TransformationMirrorAndRotate90
        || transformation == QImageIOHandler::TransformationFlipAndRotate90;
    if (rotated)
        sourceSize.transpose();

    const QSize target = targetDimensions(sourceSize.width(),
                                          sourceSize.height(),
                                          maximumWidth,
                                          maximumHeight,
                                          false);
    result.insert(QStringLiteral("sourceWidth"), sourceSize.width());
    result.insert(QStringLiteral("sourceHeight"), sourceSize.height());
    result.insert(QStringLiteral("targetWidth"), target.width());
    result.insert(QStringLiteral("targetHeight"), target.height());

    if (target == sourceSize) {
        cleanupImageCache(cachePath, {});
        result.insert(QStringLiteral("playbackPath"), source);
        result.insert(QStringLiteral("generated"), false);
        return result;
    }

    QDir().mkpath(cachePath);
    const QString identity = imageIdentity(source,
                                           sourceInfo.size(),
                                           modifiedNanoseconds(source),
                                           target.width(),
                                           target.height());
    const QString targetPath = QDir(cachePath).filePath(identity + QStringLiteral(".png"));
    if (isNonemptyFile(targetPath)) {
        QFile cached(targetPath);
        if (cached.open(QIODevice::ReadOnly)) {
            cached.setFileTime(QDateTime::currentDateTime(), QFileDevice::FileModificationTime);
            cached.close();
        }
        cleanupImageCache(cachePath, targetPath);
        result.insert(QStringLiteral("playbackPath"), targetPath);
        result.insert(QStringLiteral("generated"), true);
        return result;
    }

    QImageReader reader(source);
    reader.setAutoTransform(true);
    QSize decodeTarget = target;
    if (rotated)
        decodeTarget.transpose();
    reader.setScaledSize(decodeTarget);
    QImage image = reader.read();
    if (image.isNull()) {
        result.insert(QStringLiteral("error"), reader.errorString());
        return result;
    }
    if (image.size() != target)
        image = image.scaled(target, Qt::IgnoreAspectRatio, Qt::SmoothTransformation);

    QSaveFile output(targetPath);
    if (!output.open(QIODevice::WriteOnly)) {
        result.insert(QStringLiteral("error"), output.errorString());
        return result;
    }
    QImageWriter writer(&output, "png");
    writer.setCompression(9);
    if (!writer.write(image) || !output.commit()) {
        result.insert(QStringLiteral("error"), writer.errorString().isEmpty() ? output.errorString()
                                                                              : writer.errorString());
        return result;
    }

    cleanupImageCache(cachePath, targetPath);
    result.insert(QStringLiteral("playbackPath"), targetPath);
    result.insert(QStringLiteral("generated"), true);
    return result;
}

QString vaapiDevice()
{
    QDir dri(QStringLiteral("/dev/dri"));
    const QFileInfoList devices = dri.entryInfoList({QStringLiteral("renderD*")},
                                                    QDir::System | QDir::Files,
                                                    QDir::Name);
    for (const QFileInfo &device : devices) {
        const QFileInfo driver(QStringLiteral("/sys/class/drm/%1/device/driver").arg(device.fileName()));
        const QString name = QFileInfo(driver.canonicalFilePath()).fileName();
        if (name == QStringLiteral("amdgpu") || name == QStringLiteral("i915")
            || name == QStringLiteral("xe")) {
            return device.absoluteFilePath();
        }
    }
    return {};
}

} // namespace

class WallpaperManager::Private
{
public:
    struct Entry {
        QString source;
        QString localPath;
        QString status = QStringLiteral("checking");
        double progress = 0.0;
        QString playbackPath;
        QString thumbnailStatus = QStringLiteral("failed");
        QString thumbnailPath;
        QString error;
        qint64 sourceSize = 0;
        qint64 sourceModified = 0;
        int sourceWidth = 0;
        int sourceHeight = 0;
        double duration = 0.0;
        QString sourceFrameRate;
        int targetWidth = 0;
        int targetHeight = 0;
        QString targetFrameRate;

        QVariantMap toVariant() const
        {
            return {{QStringLiteral("localPath"), localPath},
                    {QStringLiteral("status"), status},
                    {QStringLiteral("progress"), progress},
                    {QStringLiteral("playbackPath"), playbackPath},
                    {QStringLiteral("playbackSource"), playbackPath.isEmpty() ? QString() : fileUrl(playbackPath)},
                    {QStringLiteral("thumbnailStatus"), thumbnailStatus},
                    {QStringLiteral("thumbnailSource"),
                     thumbnailStatus == QStringLiteral("ready") && !thumbnailPath.isEmpty()
                         ? fileUrl(thumbnailPath)
                         : QString()},
                    {QStringLiteral("error"), error}};
        }
    };

    struct Request {
        QStringList sources;
        int width = 1920;
        int height = 1080;
        QString preferred;
        bool rebuild = false;
    };

    struct ImageRequest {
        QString sourceUrl;
        QString localPath;
        int width = 1920;
        int height = 1080;
    };

    enum class Job : quint8 {
        None,
        DetectHardware,
        ProbeSource,
        Transcode,
        Thumbnail,
    };

    explicit Private(WallpaperManager *manager)
        : q(manager)
    {
        reconcileTimer.setSingleShot(true);
        reconcileTimer.setInterval(250);
        imageTimer.setSingleShot(true);
        imageTimer.setInterval(50);
        jobTimer.setSingleShot(true);

        QObject::connect(&reconcileTimer, &QTimer::timeout, q, [this] {
            beginScan();
            updateBusy();
        });
        QObject::connect(&imageTimer, &QTimer::timeout, q, [this] {
            beginImagePreparation();
            updateBusy();
        });
        QObject::connect(&jobTimer, &QTimer::timeout, q, [this] {
            startNextJob();
            updateBusy();
        });
        QObject::connect(&process, &QProcess::readyReadStandardOutput, q, [this] {
            consumeProcessOutput();
        });
        QObject::connect(&process, &QProcess::readyReadStandardError, q, [this] {
            standardError.append(process.readAllStandardError());
        });
        QObject::connect(&process,
                         qOverload<int, QProcess::ExitStatus>(&QProcess::finished),
                         q,
                         [this](int exitCode, QProcess::ExitStatus) { finishProcess(exitCode); });
        QObject::connect(&process, &QProcess::errorOccurred, q, [this](QProcess::ProcessError error) {
            if (error == QProcess::FailedToStart)
                QTimer::singleShot(0, q, [this] { finishProcess(-1); });
        });
        QObject::connect(&imageWatcher, &QFutureWatcher<QVariantMap>::finished, q, [this] {
            finishImagePreparation();
        });
    }

    ~Private()
    {
        QObject::disconnect(&process, nullptr, q, nullptr);
        QObject::disconnect(&imageWatcher, nullptr, q, nullptr);
        if (process.state() != QProcess::NotRunning) {
            process.kill();
            process.waitForFinished(1000);
        }
        imageWatcher.waitForFinished();
    }

    WallpaperManager *q;
    QTimer reconcileTimer;
    QTimer imageTimer;
    QTimer jobTimer;
    QProcess process;
    QFutureWatcher<QVariantMap> imageWatcher;

    QString videoCachePath;
    QString imageCachePath;
    bool powerSaver = false;
    bool onBattery = false;
    bool hardwareAvailable = false;
    bool hardwareChecked = false;
    QString hardwareDevice;
    bool lastBusy = false;
    int revision = 0;

    std::optional<Request> pendingRequest;
    Request scanRequest;
    bool scanActive = false;
    qsizetype scanIndex = 0;
    QJsonObject previousManifestEntries;
    QJsonObject newManifestEntries;
    QHash<QString, Entry> scanEntries;
    QSet<QString> retainedVideos;
    QSet<QString> retainedThumbnails;
    QString activeProbeSource;

    QHash<QString, Entry> entries;
    QHash<QString, QVariantMap> imageEntries;
    QStringList imageEntryOrder;
    QStringList knownSources;
    QString preferredSource;
    QList<QString> transcodeQueue;
    QList<QString> thumbnailQueue;
    int consecutiveThumbnails = 0;
    bool startupGracePending = true;
    bool expedited = false;

    Job job = Job::None;
    QString activeSource;
    QString activeTemporaryPath;
    bool hardwareAttempt = false;
    bool processFinishHandled = false;
    bool processCancelled = false;
    QByteArray standardOutput;
    QByteArray standardError;
    QByteArray lineBuffer;
    qint64 lastProgressUpdate = 0;

    std::optional<ImageRequest> pendingImage;
    std::optional<ImageRequest> activeImage;

    bool canTranscode() const
    {
        return !powerSaver && (hardwareAvailable || !onBattery);
    }

    bool busy() const
    {
        return scanActive || process.state() != QProcess::NotRunning || imageWatcher.isRunning()
            || reconcileTimer.isActive() || imageTimer.isActive() || jobTimer.isActive();
    }

    void updateBusy()
    {
        const bool current = busy();
        if (lastBusy == current)
            return;
        lastBusy = current;
        emit q->busyChanged();
    }

    void bumpRevision()
    {
        ++revision;
        emit q->revisionChanged();
    }

    void updateEntry(const QString &source, const std::function<void(Entry &)> &change)
    {
        auto iterator = entries.find(source);
        if (iterator == entries.end())
            return;
        change(iterator.value());
        bumpRevision();
    }

    QJsonObject loadManifest() const
    {
        QFile file(QDir(videoCachePath).filePath(QStringLiteral("manifest.json")));
        if (!file.open(QIODevice::ReadOnly))
            return {};
        const QJsonDocument document = QJsonDocument::fromJson(file.readAll());
        QJsonObject root = document.object();
        if (root.value(QStringLiteral("version")).toInt() < 1
            || !root.value(QStringLiteral("entries")).isObject()) {
            return {};
        }
        return root;
    }

    void saveManifest(const QJsonObject &manifestEntries) const
    {
        QDir().mkpath(videoCachePath);
        QSaveFile file(QDir(videoCachePath).filePath(QStringLiteral("manifest.json")));
        if (!file.open(QIODevice::WriteOnly))
            return;
        const QJsonObject root{{QStringLiteral("version"), ManifestVersion},
                               {QStringLiteral("entries"), manifestEntries}};
        file.write(QJsonDocument(root).toJson(QJsonDocument::Compact));
        file.write("\n");
        file.commit();
    }

    std::optional<Entry> entryFromManifest(const QString &source,
                                           const QFileInfo &sourceInfo,
                                           const QJsonObject &stored) const
    {
        if (stored.isEmpty() || jsonInteger(stored, QStringLiteral("sourceSize")) != sourceInfo.size()
            || jsonInteger(stored, QStringLiteral("sourceMtimeNs"))
                != modifiedNanoseconds(sourceInfo.absoluteFilePath())) {
            return std::nullopt;
        }

        Entry entry;
        entry.source = source;
        entry.localPath = WallpaperManager::localPath(source);
        entry.sourceSize = sourceInfo.size();
        entry.sourceModified = modifiedNanoseconds(sourceInfo.absoluteFilePath());
        entry.sourceWidth = stored.value(QStringLiteral("sourceWidth")).toInt();
        entry.sourceHeight = stored.value(QStringLiteral("sourceHeight")).toInt();
        entry.duration = stored.value(QStringLiteral("duration")).toDouble();
        entry.sourceFrameRate = stored.value(QStringLiteral("sourceFrameRate")).toString();
        if (entry.sourceWidth < 1 || entry.sourceHeight < 1 || entry.duration <= 0.0
            || frameRateValue(entry.sourceFrameRate) <= 0.0) {
            return std::nullopt;
        }
        return entry;
    }

    QJsonObject storedEntry(const Entry &entry) const
    {
        QFileInfo cacheInfo(entry.playbackPath);
        const bool generated = entry.status != QStringLiteral("original") && cacheInfo.isFile();
        return {{QStringLiteral("sourceSize"), QString::number(entry.sourceSize)},
                {QStringLiteral("sourceMtimeNs"), QString::number(entry.sourceModified)},
                {QStringLiteral("sourceWidth"), entry.sourceWidth},
                {QStringLiteral("sourceHeight"), entry.sourceHeight},
                {QStringLiteral("duration"), entry.duration},
                {QStringLiteral("sourceFrameRate"), entry.sourceFrameRate},
                {QStringLiteral("targetWidth"), entry.targetWidth},
                {QStringLiteral("targetHeight"), entry.targetHeight},
                {QStringLiteral("targetFrameRate"), entry.targetFrameRate},
                {QStringLiteral("cachePath"), generated ? entry.playbackPath : QString()},
                {QStringLiteral("cacheSize"), generated ? QString::number(cacheInfo.size()) : QStringLiteral("0")},
                {QStringLiteral("cacheMtimeNs"),
                 generated ? QString::number(modifiedNanoseconds(cacheInfo.absoluteFilePath()))
                           : QStringLiteral("0")},
                {QStringLiteral("thumbnailPath"), entry.thumbnailPath}};
    }

    bool storedCacheMatches(const QJsonObject &stored, const QString &path) const
    {
        const QFileInfo info(path);
        return stored.value(QStringLiteral("cachePath")).toString() == path && info.isFile()
            && info.size() > 0 && jsonInteger(stored, QStringLiteral("cacheSize")) == info.size()
            && jsonInteger(stored, QStringLiteral("cacheMtimeNs"))
                == modifiedNanoseconds(info.absoluteFilePath());
    }

    void startCommand(const QString &program, QStringList arguments, bool lowPriority)
    {
        processFinishHandled = false;
        standardOutput.clear();
        standardError.clear();
        lineBuffer.clear();
        process.setProcessChannelMode(QProcess::SeparateChannels);

        Ateria::setBackgroundScheduling(process, lowPriority, 19);
        process.start(program, std::move(arguments), QIODevice::ReadOnly);
        updateBusy();
    }

    void detectHardware()
    {
        hardwareDevice = vaapiDevice();
        const QString ffmpeg = QStandardPaths::findExecutable(QStringLiteral("ffmpeg"));
        if (hardwareDevice.isEmpty() || ffmpeg.isEmpty()) {
            hardwareChecked = true;
            hardwareAvailable = false;
            continueScanAfterDetection();
            return;
        }
        job = Job::DetectHardware;
        startCommand(ffmpeg, {QStringLiteral("-hide_banner"), QStringLiteral("-encoders")}, true);
    }

    void continueScanAfterDetection()
    {
        processNextScanSource();
        updateBusy();
    }

    void beginScan()
    {
        if (!pendingRequest || process.state() != QProcess::NotRunning || scanActive)
            return;

        scanRequest = *pendingRequest;
        pendingRequest.reset();
        scanActive = true;
        scanIndex = 0;
        scanEntries.clear();
        retainedVideos.clear();
        retainedThumbnails.clear();
        newManifestEntries = {};

        QDir().mkpath(videoCachePath);
        QDir().mkpath(QDir(videoCachePath).filePath(QStringLiteral("thumbnails")));
        const QJsonObject manifest = loadManifest();
        previousManifestEntries = manifest.value(QStringLiteral("entries")).toObject();

        if (scanRequest.rebuild) {
            removeMatchingFiles(videoCachePath,
                                {QStringLiteral("*.mp4"), QStringLiteral("*.partial.*")});
            removeMatchingFiles(QDir(videoCachePath).filePath(QStringLiteral("thumbnails")),
                                {QStringLiteral("*.jpg"), QStringLiteral("*.partial.*")});
        }

        if (scanRequest.sources.isEmpty())
            finishScan();
        else if (!hardwareChecked)
            detectHardware();
        else
            processNextScanSource();
        updateBusy();
    }

    void processNextScanSource()
    {
        if (!scanActive)
            return;
        // Do not spend time probing the rest of a snapshot that has already
        // been superseded. finishScan() preserves metadata discovered so far
        // and immediately starts the current request.
        if (pendingRequest) {
            finishScan();
            return;
        }
        if (scanIndex >= scanRequest.sources.size()) {
            finishScan();
            return;
        }

        const QString source = scanRequest.sources.at(scanIndex);
        const QString path = WallpaperManager::localPath(source);
        const QFileInfo info(path);
        const QJsonObject stored = previousManifestEntries.value(path).toObject();
        if (!info.isFile()) {
            Entry entry;
            entry.source = source;
            entry.localPath = path;
            entry.status = QStringLiteral("invalid");
            entry.error = QCoreApplication::translate("WallpaperManager", "The wallpaper video no longer exists.");
            scanEntries.insert(source, entry);
            ++scanIndex;
            processNextScanSource();
            return;
        }

        const std::optional<Entry> cachedMetadata = entryFromManifest(source, info, stored);
        if (cachedMetadata) {
            finishScannedSource(*cachedMetadata, stored);
            return;
        }

        const QString ffprobe = QStandardPaths::findExecutable(QStringLiteral("ffprobe"));
        if (ffprobe.isEmpty()) {
            Entry entry;
            entry.source = source;
            entry.localPath = path;
            entry.status = QStringLiteral("invalid");
            entry.error = QCoreApplication::translate("WallpaperManager", "FFmpeg video support is not installed.");
            scanEntries.insert(source, entry);
            ++scanIndex;
            processNextScanSource();
            return;
        }

        activeProbeSource = source;
        job = Job::ProbeSource;
        startCommand(ffprobe,
                     {QStringLiteral("-v"),
                      QStringLiteral("error"),
                      QStringLiteral("-select_streams"),
                      QStringLiteral("v:0"),
                      QStringLiteral("-show_entries"),
                      QStringLiteral("stream=width,height,avg_frame_rate,r_frame_rate:format=duration"),
                      QStringLiteral("-of"),
                      QStringLiteral("json"),
                      path},
                     true);
    }

    void finishScannedSource(Entry entry, const QJsonObject &stored)
    {
        const QSize target = targetDimensions(entry.sourceWidth,
                                              entry.sourceHeight,
                                              scanRequest.width,
                                              scanRequest.height,
                                              true);
        entry.targetWidth = target.width();
        entry.targetHeight = target.height();
        const bool requiresTranscode = target.width() != entry.sourceWidth
            || target.height() != entry.sourceHeight;
        entry.targetFrameRate = requiresTranscode && frameRateValue(entry.sourceFrameRate) > MaximumFrameRate
            ? QStringLiteral("30")
            : entry.sourceFrameRate;
        entry.thumbnailPath = QDir(videoCachePath)
                                  .filePath(QStringLiteral("thumbnails/%1.jpg")
                                                .arg(thumbnailIdentity(entry.localPath,
                                                                       entry.sourceSize,
                                                                       entry.sourceModified)));
        entry.thumbnailStatus = isNonemptyFile(entry.thumbnailPath) ? QStringLiteral("ready")
                                                                    : QStringLiteral("queued");
        retainedThumbnails.insert(entry.thumbnailPath);

        if (!requiresTranscode) {
            entry.status = QStringLiteral("original");
            entry.progress = 1.0;
            entry.playbackPath = entry.localPath;
        } else {
            const QString generatedPath = QDir(videoCachePath)
                                              .filePath(videoIdentity(entry.localPath,
                                                                      entry.sourceSize,
                                                                      entry.sourceModified,
                                                                      entry.targetWidth,
                                                                      entry.targetHeight,
                                                                      entry.targetFrameRate)
                                                        + QStringLiteral(".mp4"));
            const bool storedProfileMatches = stored.value(QStringLiteral("targetWidth")).toInt()
                    == entry.targetWidth
                && stored.value(QStringLiteral("targetHeight")).toInt() == entry.targetHeight
                && normalizedFrameRate(stored.value(QStringLiteral("targetFrameRate")).toString())
                    == normalizedFrameRate(entry.targetFrameRate);
            const QString storedPath = stored.value(QStringLiteral("cachePath")).toString();
            const QString reusablePath = storedProfileMatches ? storedPath : QString();
            if (!scanRequest.rebuild && !reusablePath.isEmpty()
                && storedCacheMatches(stored, reusablePath)) {
                entry.status = QStringLiteral("ready");
                entry.progress = 1.0;
                entry.playbackPath = reusablePath;
                retainedVideos.insert(reusablePath);
            } else {
                QFile::remove(generatedPath);
                entry.status = QStringLiteral("queued");
                entry.progress = 0.0;
                entry.playbackPath = generatedPath;
            }
        }

        newManifestEntries.insert(entry.localPath, storedEntry(entry));
        scanEntries.insert(entry.source, entry);
        ++scanIndex;
        processNextScanSource();
    }

    void failScannedSource(const QString &message)
    {
        Entry entry;
        entry.source = activeProbeSource;
        entry.localPath = WallpaperManager::localPath(activeProbeSource);
        entry.status = QStringLiteral("invalid");
        entry.error = message;
        scanEntries.insert(entry.source, entry);
        activeProbeSource.clear();
        ++scanIndex;
        processNextScanSource();
    }

    void finishScan()
    {
        // A newer request supersedes this snapshot. Preserve the metadata that
        // was already discovered, but do not publish stale entries or clean
        // files against an obsolete source list and display profile.
        if (pendingRequest) {
            QJsonObject mergedEntries = previousManifestEntries;
            for (auto iterator = newManifestEntries.constBegin(); iterator != newManifestEntries.constEnd(); ++iterator)
                mergedEntries.insert(iterator.key(), iterator.value());
            saveManifest(mergedEntries);
            scanActive = false;
            reconcileTimer.start(0);
            updateBusy();
            return;
        }

        removeUnretained(videoCachePath, {QStringLiteral("*.mp4")}, retainedVideos);
        removeMatchingFiles(videoCachePath, {QStringLiteral("*.partial.*")});
        const QString thumbnailDirectory = QDir(videoCachePath).filePath(QStringLiteral("thumbnails"));
        removeUnretained(thumbnailDirectory, {QStringLiteral("*.jpg")}, retainedThumbnails);
        removeMatchingFiles(thumbnailDirectory, {QStringLiteral("*.partial.*")});
        saveManifest(newManifestEntries);

        entries = scanEntries;
        transcodeQueue.clear();
        thumbnailQueue.clear();
        for (const QString &source : scanRequest.sources) {
            const Entry entry = entries.value(source);
            if (entry.status == QStringLiteral("queued"))
                transcodeQueue.append(source);
            if (entry.thumbnailStatus == QStringLiteral("queued"))
                thumbnailQueue.append(source);
        }
        prioritize(transcodeQueue, scanRequest.preferred);
        prioritize(thumbnailQueue, scanRequest.preferred);
        consecutiveThumbnails = 0;

        if (preferredSource != scanRequest.preferred) {
            preferredSource = scanRequest.preferred;
            emit q->preferredSourceChanged();
        }
        scanActive = false;
        bumpRevision();

        const int delay = expedited ? 50 : (startupGracePending ? 2500 : 250);
        startupGracePending = false;
        expedited = false;
        scheduleNext(delay);
        updateBusy();
    }

    static void prioritize(QList<QString> &queue, const QString &preferred)
    {
        std::stable_sort(queue.begin(), queue.end(), [&](const QString &left, const QString &right) {
            return left == preferred && right != preferred;
        });
    }

    static void removeUnretained(const QString &directory,
                                 const QStringList &filters,
                                 const QSet<QString> &retained)
    {
        QDir dir(directory);
        const QFileInfoList files = dir.entryInfoList(filters, QDir::Files | QDir::NoSymLinks);
        for (const QFileInfo &file : files) {
            if (!retained.contains(file.absoluteFilePath()))
                QFile::remove(file.absoluteFilePath());
        }
    }

    void scheduleNext(int delay)
    {
        if (!pendingRequest && transcodeQueue.isEmpty() && thumbnailQueue.isEmpty()) {
            updateBusy();
            return;
        }
        jobTimer.start(std::max(0, delay));
        updateBusy();
    }

    void startNextJob()
    {
        if (pendingRequest) {
            beginScan();
            return;
        }
        if (scanActive || process.state() != QProcess::NotRunning)
            return;

        const bool transcodeAllowed = canTranscode() && !transcodeQueue.isEmpty()
            && (!onBattery || transcodeQueue.first() == preferredSource);
        const bool preferredTranscode = transcodeAllowed && transcodeQueue.first() == preferredSource;
        const bool preferredThumbnail = !thumbnailQueue.isEmpty()
            && thumbnailQueue.first() == preferredSource;
        const bool thumbnailBurst = !thumbnailQueue.isEmpty()
            && (!transcodeAllowed || consecutiveThumbnails < 4);

        if (preferredThumbnail || (!preferredTranscode && thumbnailBurst)) {
            startThumbnail();
        } else if (transcodeAllowed) {
            startTranscode();
        }
        updateBusy();
    }

    void startTranscode()
    {
        if (transcodeQueue.isEmpty())
            return;
        activeSource = transcodeQueue.takeFirst();
        auto iterator = entries.find(activeSource);
        if (iterator == entries.end() || iterator->status != QStringLiteral("queued")) {
            QTimer::singleShot(0, q, [this] { startNextJob(); });
            return;
        }
        iterator->status = QStringLiteral("converting");
        iterator->progress = 0.0;
        iterator->error.clear();
        bumpRevision();
        consecutiveThumbnails = 0;
        job = Job::Transcode;
        lastProgressUpdate = 0;
        activeTemporaryPath = iterator->playbackPath + QStringLiteral(".partial.%1.mp4")
                                                           .arg(QCoreApplication::applicationPid());
        QFile::remove(activeTemporaryPath);
        hardwareAttempt = hardwareAvailable;
        startTranscodeProcess();
    }

    void startTranscodeProcess()
    {
        const Entry entry = entries.value(activeSource);
        const QString ffmpeg = QStandardPaths::findExecutable(QStringLiteral("ffmpeg"));
        if (ffmpeg.isEmpty()) {
            finishTranscodeFailure(QCoreApplication::translate("WallpaperManager",
                                                               "FFmpeg video support is not installed."));
            return;
        }

        QStringList arguments{QStringLiteral("-hide_banner"),
                              QStringLiteral("-loglevel"),
                              QStringLiteral("error"),
                              QStringLiteral("-y")};
        if (hardwareAttempt) {
            arguments.append({QStringLiteral("-vaapi_device"),
                              hardwareDevice,
                              QStringLiteral("-hwaccel"),
                              QStringLiteral("vaapi"),
                              QStringLiteral("-hwaccel_device"),
                              hardwareDevice,
                              QStringLiteral("-hwaccel_output_format"),
                              QStringLiteral("vaapi"),
                              QStringLiteral("-i"),
                              entry.localPath,
                              QStringLiteral("-map"),
                              QStringLiteral("0:v:0"),
                              QStringLiteral("-an"),
                              QStringLiteral("-vf"),
                              QStringLiteral("scale_vaapi=w=%1:h=%2").arg(entry.targetWidth).arg(entry.targetHeight),
                              QStringLiteral("-c:v"),
                              QStringLiteral("h264_vaapi"),
                              QStringLiteral("-rc_mode"),
                              QStringLiteral("CQP"),
                              QStringLiteral("-qp"),
                              QStringLiteral("20"),
                              QStringLiteral("-profile:v"),
                              QStringLiteral("high")});
        } else {
            arguments.append({QStringLiteral("-i"),
                              entry.localPath,
                              QStringLiteral("-map"),
                              QStringLiteral("0:v:0"),
                              QStringLiteral("-an"),
                              QStringLiteral("-vf"),
                              QStringLiteral("scale=%1:%2").arg(entry.targetWidth).arg(entry.targetHeight),
                              QStringLiteral("-c:v"),
                              QStringLiteral("libx264"),
                              QStringLiteral("-preset"),
                              QStringLiteral("medium"),
                              QStringLiteral("-crf"),
                              QStringLiteral("20"),
                              QStringLiteral("-threads"),
                              QStringLiteral("1")});
        }
        if (frameRateValue(entry.sourceFrameRate) > MaximumFrameRate)
            arguments.append({QStringLiteral("-r"), QStringLiteral("30")});
        if (!hardwareAttempt)
            arguments.append({QStringLiteral("-pix_fmt"), QStringLiteral("yuv420p")});
        arguments.append({QStringLiteral("-movflags"),
                          QStringLiteral("+faststart"),
                          QStringLiteral("-stats_period"),
                          QStringLiteral("0.1"),
                          QStringLiteral("-progress"),
                          QStringLiteral("pipe:1"),
                          QStringLiteral("-nostats"),
                          activeTemporaryPath});
        startCommand(ffmpeg, arguments, !hardwareAttempt);
    }

    void startThumbnail()
    {
        if (thumbnailQueue.isEmpty())
            return;
        activeSource = thumbnailQueue.takeFirst();
        auto iterator = entries.find(activeSource);
        if (iterator == entries.end() || iterator->thumbnailStatus != QStringLiteral("queued")) {
            QTimer::singleShot(0, q, [this] { startNextJob(); });
            return;
        }
        iterator->thumbnailStatus = QStringLiteral("generating");
        bumpRevision();
        ++consecutiveThumbnails;
        job = Job::Thumbnail;
        activeTemporaryPath = QFileInfo(iterator->thumbnailPath)
                                  .dir()
                                  .filePath(QFileInfo(iterator->thumbnailPath).completeBaseName()
                                            + QStringLiteral(".partial.%1.jpg")
                                                  .arg(QCoreApplication::applicationPid()));
        QFile::remove(activeTemporaryPath);
        QDir().mkpath(QFileInfo(activeTemporaryPath).dir().absolutePath());

        const QString input = iterator->status == QStringLiteral("ready")
            && isNonemptyFile(iterator->playbackPath)
            ? iterator->playbackPath
            : iterator->localPath;
        const QString ffmpeg = QStandardPaths::findExecutable(QStringLiteral("ffmpeg"));
        if (ffmpeg.isEmpty()) {
            finishThumbnail(false);
            return;
        }
        startCommand(ffmpeg,
                     {QStringLiteral("-hide_banner"),
                      QStringLiteral("-loglevel"),
                      QStringLiteral("error"),
                      QStringLiteral("-y"),
                      QStringLiteral("-threads"),
                      QStringLiteral("1"),
                      QStringLiteral("-i"),
                      input,
                      QStringLiteral("-map"),
                      QStringLiteral("0:v:0"),
                      QStringLiteral("-an"),
                      QStringLiteral("-frames:v"),
                      QStringLiteral("1"),
                      QStringLiteral("-vf"),
                      QStringLiteral("scale=%1:-2:force_original_aspect_ratio=decrease").arg(ThumbnailWidth),
                      QStringLiteral("-q:v"),
                      QStringLiteral("4"),
                      activeTemporaryPath},
                     true);
    }

    void consumeProcessOutput()
    {
        const QByteArray data = process.readAllStandardOutput();
        if (job != Job::Transcode) {
            standardOutput.append(data);
            return;
        }
        lineBuffer.append(data);
        qsizetype newline = -1;
        while ((newline = lineBuffer.indexOf('\n')) >= 0) {
            const QByteArray line = lineBuffer.left(newline).trimmed();
            lineBuffer.remove(0, newline + 1);
            const qsizetype separator = line.indexOf('=');
            if (separator < 0)
                continue;
            const QByteArray key = line.left(separator);
            if (key != "out_time_us" && key != "out_time_ms")
                continue;
            bool ok = false;
            const double microseconds = line.mid(separator + 1).toDouble(&ok);
            const Entry entry = entries.value(activeSource);
            if (!ok || entry.duration <= 0.0)
                continue;
            const double progress = std::clamp(microseconds / 1'000'000.0 / entry.duration, 0.0, 0.99);
            const qint64 now = QDateTime::currentMSecsSinceEpoch();
            if (lastProgressUpdate != 0 && progress < 0.99 && now - lastProgressUpdate < 150)
                continue;
            lastProgressUpdate = now;
            updateEntry(activeSource, [progress](Entry &value) { value.progress = progress; });
        }
    }

    void finishProcess(int exitCode)
    {
        if (processFinishHandled)
            return;
        processFinishHandled = true;
        const Job completedJob = job;
        if (completedJob != Job::Transcode)
            standardOutput.append(process.readAllStandardOutput());
        else
            process.readAllStandardOutput();
        standardError.append(process.readAllStandardError());
        job = Job::None;

        if (processCancelled) {
            processCancelled = false;
            QFile::remove(activeTemporaryPath);
            clearActiveJob();
            if (pendingRequest)
                reconcileTimer.start(0);
            else
                scheduleNext(50);
            updateBusy();
            return;
        }

        switch (completedJob) {
        case Job::DetectHardware: {
            const bool oldCanTranscode = canTranscode();
            const bool oldHardware = hardwareAvailable;
            hardwareAvailable = exitCode == 0 && standardOutput.contains("h264_vaapi");
            hardwareChecked = true;
            if (oldHardware != hardwareAvailable)
                emit q->hardwareAvailableChanged();
            if (oldCanTranscode != canTranscode())
                emit q->canTranscodeChanged();
            continueScanAfterDetection();
            break;
        }
        case Job::ProbeSource:
            finishProbe(exitCode);
            break;
        case Job::Transcode:
            finishTranscode(exitCode);
            break;
        case Job::Thumbnail:
            finishThumbnail(exitCode == 0 && isNonemptyFile(activeTemporaryPath));
            break;
        case Job::None:
            break;
        }
        updateBusy();
    }

    void finishProbe(int exitCode)
    {
        const QJsonObject root = QJsonDocument::fromJson(standardOutput).object();
        const QJsonArray streams = root.value(QStringLiteral("streams")).toArray();
        const QJsonObject stream = streams.isEmpty() ? QJsonObject() : streams.at(0).toObject();
        const int width = stream.value(QStringLiteral("width")).toInt();
        const int height = stream.value(QStringLiteral("height")).toInt();
        const double duration = root.value(QStringLiteral("format"))
                                    .toObject()
                                    .value(QStringLiteral("duration"))
                                    .toString()
                                    .toDouble();
        const QString frameRate = normalizedFrameRate(stream.value(QStringLiteral("avg_frame_rate")).toString(),
                                                      stream.value(QStringLiteral("r_frame_rate")).toString());
        if (exitCode != 0 || width < 1 || height < 1 || duration <= 0.0 || frameRate.isEmpty()) {
            failScannedSource(QCoreApplication::translate("WallpaperManager",
                                                          "This video format could not be read."));
            return;
        }

        const QString source = activeProbeSource;
        const QFileInfo info(WallpaperManager::localPath(source));
        Entry entry;
        entry.source = source;
        entry.localPath = info.absoluteFilePath();
        entry.sourceSize = info.size();
        entry.sourceModified = modifiedNanoseconds(info.absoluteFilePath());
        entry.sourceWidth = width;
        entry.sourceHeight = height;
        entry.duration = duration;
        entry.sourceFrameRate = frameRate;
        activeProbeSource.clear();
        finishScannedSource(entry, previousManifestEntries.value(entry.localPath).toObject());
    }

    void finishTranscode(int exitCode)
    {
        if (exitCode == 0 && isNonemptyFile(activeTemporaryPath)) {
            Entry &entry = entries[activeSource];
            if (replaceFile(activeTemporaryPath, entry.playbackPath)) {
                entry.status = QStringLiteral("ready");
                entry.progress = 1.0;
                entry.error.clear();
                updateManifestEntry(entry);
                bumpRevision();
                clearActiveJob();
                scheduleNext(50);
                return;
            }
        }

        QFile::remove(activeTemporaryPath);
        if (hardwareAttempt) {
            hardwareAttempt = false;
            job = Job::Transcode;
            startTranscodeProcess();
            return;
        }
        const QString message = standardError.trimmed().isEmpty()
            ? QCoreApplication::translate("WallpaperManager", "The wallpaper video could not be converted.")
            : QCoreApplication::translate("WallpaperManager", "FFmpeg could not convert this wallpaper video.");
        finishTranscodeFailure(message);
    }

    void finishTranscodeFailure(const QString &message)
    {
        updateEntry(activeSource, [&](Entry &entry) {
            entry.status = QStringLiteral("failed");
            entry.progress = 0.0;
            entry.error = message;
        });
        clearActiveJob();
        scheduleNext(50);
    }

    void finishThumbnail(bool success)
    {
        auto iterator = entries.find(activeSource);
        if (iterator != entries.end()) {
            if (success) {
                success = replaceFile(activeTemporaryPath, iterator->thumbnailPath);
            }
            if (!success)
                QFile::remove(activeTemporaryPath);
            iterator->thumbnailStatus = success ? QStringLiteral("ready") : QStringLiteral("failed");
            bumpRevision();
        }
        clearActiveJob();
        scheduleNext(50);
    }

    void clearActiveJob()
    {
        job = Job::None;
        activeSource.clear();
        activeTemporaryPath.clear();
        hardwareAttempt = false;
    }

    void updateManifestEntry(const Entry &entry)
    {
        QJsonObject manifest = loadManifest();
        QJsonObject manifestEntries = manifest.value(QStringLiteral("entries")).toObject();
        manifestEntries.insert(entry.localPath, storedEntry(entry));
        saveManifest(manifestEntries);
    }

    void beginImagePreparation()
    {
        if (imageWatcher.isRunning() || !pendingImage)
            return;
        activeImage = pendingImage;
        pendingImage.reset();
        const ImageRequest request = *activeImage;
        const QString cache = imageCachePath;
        imageWatcher.setFuture(QtConcurrent::run([request, cache] {
            return prepareImageCache(request.localPath, cache, request.width, request.height);
        }));
        updateBusy();
    }

    void finishImagePreparation()
    {
        if (!activeImage)
            return;
        const ImageRequest request = *activeImage;
        activeImage.reset();
        const QVariantMap result = imageWatcher.result();
        const QString playbackPath = result.value(QStringLiteral("playbackPath")).toString();
        QVariantMap entry;
        if (!playbackPath.isEmpty()) {
            entry = result;
            entry.insert(QStringLiteral("status"),
                         result.value(QStringLiteral("generated")).toBool() ? QStringLiteral("ready")
                                                                            : QStringLiteral("original"));
            entry.insert(QStringLiteral("playbackSource"), fileUrl(playbackPath));
            entry.insert(QStringLiteral("error"), QString());
        } else {
            entry.insert(QStringLiteral("status"), QStringLiteral("failed"));
            entry.insert(QStringLiteral("playbackSource"), request.sourceUrl);
            entry.insert(QStringLiteral("error"), result.value(QStringLiteral("error")));
        }
        imageEntries.insert(request.sourceUrl, entry);
        imageEntryOrder.removeAll(request.sourceUrl);
        imageEntryOrder.append(request.sourceUrl);
        while (imageEntryOrder.size() > 32)
            imageEntries.remove(imageEntryOrder.takeFirst());
        bumpRevision();
        if (pendingImage)
            imageTimer.start();
        updateBusy();
    }
};

WallpaperManager::WallpaperManager(QObject *parent)
    : QObject(parent)
    , d(std::make_unique<Private>(this))
{
}

WallpaperManager::~WallpaperManager() = default;

bool WallpaperManager::busy() const
{
    return d->busy();
}

bool WallpaperManager::hardwareAvailable() const
{
    return d->hardwareAvailable;
}

bool WallpaperManager::canTranscode() const
{
    return d->canTranscode();
}

QStringList WallpaperManager::knownSources() const
{
    return d->knownSources;
}

QString WallpaperManager::preferredSource() const
{
    return d->preferredSource;
}

int WallpaperManager::revision() const
{
    return d->revision;
}

void WallpaperManager::configure(const QString &videoCachePath, const QString &imageCachePath)
{
    const QString video = localPath(videoCachePath);
    const QString images = localPath(imageCachePath);
    if (video.isEmpty() || images.isEmpty())
        return;
    d->videoCachePath = QDir::cleanPath(video);
    d->imageCachePath = QDir::cleanPath(images);
    QDir().mkpath(d->videoCachePath);
    QDir().mkpath(d->imageCachePath);
}

void WallpaperManager::setPowerState(bool powerSaver, bool onBattery)
{
    const bool oldCanTranscode = d->canTranscode();
    d->powerSaver = powerSaver;
    d->onBattery = onBattery;
    if (oldCanTranscode != d->canTranscode())
        emit canTranscodeChanged();
    if (d->canTranscode())
        d->scheduleNext(50);
}

void WallpaperManager::reconcile(const QVariantList &sources,
                                 int width,
                                 int height,
                                 const QString &preferredSource,
                                 bool forceRebuild)
{
    if (d->videoCachePath.isEmpty())
        return;
    QStringList uniqueSources;
    QSet<QString> seen;
    for (const QVariant &value : sources) {
        const QString source = value.toString();
        if (!isVideo(source) || seen.contains(source))
            continue;
        seen.insert(source);
        uniqueSources.append(source);
    }

    if (d->knownSources != uniqueSources) {
        d->knownSources = uniqueSources;
        emit knownSourcesChanged();
    }
    d->pendingRequest = Private::Request{uniqueSources,
                                         std::max(2, width),
                                         std::max(2, height),
                                         preferredSource,
                                         forceRebuild};
    const bool profileChanged = d->scanRequest.width != std::max(2, width)
        || d->scanRequest.height != std::max(2, height);
    const bool activeSourceRemoved = !d->activeSource.isEmpty()
        && !uniqueSources.contains(d->activeSource);
    if ((d->job == Private::Job::Transcode || d->job == Private::Job::Thumbnail)
        && d->process.state() != QProcess::NotRunning
        && (profileChanged || activeSourceRemoved)) {
        d->processCancelled = true;
        d->process.kill();
    }
    d->reconcileTimer.start();
    d->updateBusy();
}

void WallpaperManager::rebuild()
{
    if (d->busy() || d->knownSources.isEmpty())
        return;
    for (auto iterator = d->entries.begin(); iterator != d->entries.end(); ++iterator) {
        if (iterator->status == QStringLiteral("original"))
            continue;
        iterator->status = QStringLiteral("checking");
        iterator->progress = 0.0;
        iterator->playbackPath.clear();
        iterator->error.clear();
    }
    d->bumpRevision();
    reconcile(QVariantList(d->knownSources.cbegin(), d->knownSources.cend()),
              d->scanRequest.width,
              d->scanRequest.height,
              d->preferredSource,
              true);
}

void WallpaperManager::expeditePendingWork()
{
    const bool discoveryPending = d->scanActive || d->reconcileTimer.isActive() || d->pendingRequest;
    const bool workPending = d->jobTimer.isActive() || !d->transcodeQueue.isEmpty()
        || !d->thumbnailQueue.isEmpty();
    if (!d->startupGracePending && !discoveryPending && !workPending)
        return;
    d->expedited = true;
    if (d->jobTimer.isActive())
        d->scheduleNext(50);
}

void WallpaperManager::prepareImage(const QString &source, int width, int height)
{
    if (!isImage(source) || !isLocalFile(source) || d->imageCachePath.isEmpty())
        return;
    const Private::ImageRequest request{source,
                                        localPath(source),
                                        std::max(1, width),
                                        std::max(1, height)};
    d->pendingImage = request;
    if (!d->imageEntries.contains(source)) {
        d->imageEntries.insert(source,
                               {{QStringLiteral("status"), QStringLiteral("checking")},
                                {QStringLiteral("playbackSource"), QString()},
                                {QStringLiteral("error"), QString()}});
        d->bumpRevision();
    }
    d->imageTimer.start();
    d->updateBusy();
}

QVariantMap WallpaperManager::entryFor(const QString &source) const
{
    const auto iterator = d->entries.constFind(source);
    return iterator == d->entries.cend() ? QVariantMap() : iterator->toVariant();
}

QString WallpaperManager::imagePlaybackSource(const QString &source) const
{
    return d->imageEntries.value(source).value(QStringLiteral("playbackSource")).toString();
}

bool WallpaperManager::isSelectable(const QString &source) const
{
    if (!isVideo(source))
        return true;
    const auto iterator = d->entries.constFind(source);
    return iterator != d->entries.cend()
        && (iterator->status == QStringLiteral("ready") || iterator->status == QStringLiteral("original"));
}

QString WallpaperManager::playbackSource(const QString &source) const
{
    const auto iterator = d->entries.constFind(source);
    if (iterator == d->entries.cend() || !isSelectable(source))
        return {};
    return fileUrl(iterator->playbackPath);
}

QString WallpaperManager::localPath(const QString &source)
{
    const QUrl url(source);
    return url.isLocalFile() ? url.toLocalFile() : source;
}

bool WallpaperManager::isVideo(const QString &source)
{
    const QString suffix = QFileInfo(localPath(source)).suffix().toLower();
    return suffix == QStringLiteral("mp4") || suffix == QStringLiteral("webm")
        || suffix == QStringLiteral("mkv") || suffix == QStringLiteral("gif");
}

bool WallpaperManager::isImage(const QString &source)
{
    const QString suffix = QFileInfo(localPath(source)).suffix().toLower();
    return suffix == QStringLiteral("png") || suffix == QStringLiteral("jpg")
        || suffix == QStringLiteral("jpeg") || suffix == QStringLiteral("webp");
}

bool WallpaperManager::isLocalFile(const QString &source)
{
    const QUrl url(source);
    return url.isLocalFile() || QDir::isAbsolutePath(source);
}
