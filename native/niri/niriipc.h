#pragma once

#include <QObject>
#include <QVariantMap>
#include <QtQmlIntegration>

#include <memory>

class NiriIpc : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(bool available READ available NOTIFY connectedChanged)
    Q_PROPERTY(bool connected READ connected NOTIFY connectedChanged)
    Q_PROPERTY(QString lastError READ lastError NOTIFY lastErrorChanged)

public:
    explicit NiriIpc(QObject *parent = nullptr);
    ~NiriIpc() override;

    bool available() const;
    bool connected() const;
    QString lastError() const;

    Q_INVOKABLE void initialize();
    Q_INVOKABLE bool focusWorkspace(int workspaceIndex,
                                    const QString &outputName = {},
                                    const QString &focusedOutputName = {});
    Q_INVOKABLE bool focusWindow(double windowId);
    Q_INVOKABLE bool quit(bool skipConfirmation = true);

signals:
    void connectedChanged();
    void lastErrorChanged();
    void eventReceived(const QVariantMap &event);
    void eventParseFailed(const QString &line, const QString &message);
    void actionCompleted(const QString &action);
    void actionFailed(const QString &action, const QString &message);

private:
    class Private;
    std::unique_ptr<Private> d;
};
