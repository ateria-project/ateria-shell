#pragma once

#include <QObject>
#include <QStringList>
#include <QVariantMap>
#include <QtQmlIntegration>

#include <memory>

class WallpaperManager : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)
    Q_PROPERTY(bool hardwareAvailable READ hardwareAvailable NOTIFY hardwareAvailableChanged)
    Q_PROPERTY(bool canTranscode READ canTranscode NOTIFY canTranscodeChanged)
    Q_PROPERTY(QStringList knownSources READ knownSources NOTIFY knownSourcesChanged)
    Q_PROPERTY(QString preferredSource READ preferredSource NOTIFY preferredSourceChanged)
    Q_PROPERTY(int revision READ revision NOTIFY revisionChanged)

public:
    explicit WallpaperManager(QObject *parent = nullptr);
    ~WallpaperManager() override;

    bool busy() const;
    bool hardwareAvailable() const;
    bool canTranscode() const;
    QStringList knownSources() const;
    QString preferredSource() const;
    int revision() const;

    Q_INVOKABLE void configure(const QString &videoCachePath, const QString &imageCachePath);
    Q_INVOKABLE void setPowerState(bool powerSaver, bool onBattery);
    Q_INVOKABLE void reconcile(const QVariantList &sources,
                               int width,
                               int height,
                               const QString &preferredSource,
                               bool forceRebuild = false);
    Q_INVOKABLE void rebuild();
    Q_INVOKABLE void expeditePendingWork();
    Q_INVOKABLE void prepareImage(const QString &source, int width, int height);

    Q_INVOKABLE QVariantMap entryFor(const QString &source) const;
    Q_INVOKABLE QString imagePlaybackSource(const QString &source) const;
    Q_INVOKABLE bool isSelectable(const QString &source) const;
    Q_INVOKABLE QString playbackSource(const QString &source) const;

    Q_INVOKABLE static QString localPath(const QString &source);
    Q_INVOKABLE static bool isVideo(const QString &source);
    Q_INVOKABLE static bool isImage(const QString &source);
    Q_INVOKABLE static bool isLocalFile(const QString &source);

signals:
    void busyChanged();
    void hardwareAvailableChanged();
    void canTranscodeChanged();
    void knownSourcesChanged();
    void preferredSourceChanged();
    void revisionChanged();

private:
    class Private;
    std::unique_ptr<Private> d;
};
