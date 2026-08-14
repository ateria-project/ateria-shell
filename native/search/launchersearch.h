#pragma once

#include <QObject>
#include <QString>
#include <QVariant>
#include <QtQmlIntegration>

class LauncherSearch : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

public:
    explicit LauncherSearch(QObject *parent = nullptr);

    Q_INVOKABLE QString applicationKey(const QVariant &application) const;
};
