#pragma once

#include <QObject>
#include <QString>
#include <QVariantList>
#include <QVariantMap>
#include <QtQmlIntegration>

#include <memory>

class LauncherSearchModel : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(QVariantList applications READ applications WRITE setApplications NOTIFY applicationsChanged)
    Q_PROPERTY(QString query READ query WRITE setQuery NOTIFY queryChanged)
    Q_PROPERTY(QVariantMap usageHistory READ usageHistory WRITE setUsageHistory NOTIFY usageHistoryChanged)
    Q_PROPERTY(qint64 rankingTime READ rankingTime WRITE setRankingTime NOTIFY rankingTimeChanged)
    Q_PROPERTY(QVariantList results READ results NOTIFY resultsChanged)

public:
    explicit LauncherSearchModel(QObject *parent = nullptr);
    ~LauncherSearchModel() override;

    QVariantList applications() const;
    void setApplications(const QVariantList &applications);

    QString query() const;
    void setQuery(const QString &query);

    QVariantMap usageHistory() const;
    void setUsageHistory(const QVariantMap &history);

    qint64 rankingTime() const;
    void setRankingTime(qint64 time);

    QVariantList results() const;

    static QString applicationKey(const QVariant &application);
    static int boundedEditDistance(const QString &left, const QString &right, int limit);

signals:
    void applicationsChanged();
    void queryChanged();
    void usageHistoryChanged();
    void rankingTimeChanged();
    void resultsChanged();

private:
    class Private;
    std::unique_ptr<Private> d;
};
