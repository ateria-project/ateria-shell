#pragma once

#include <QDBusContext>
#include <QDBusObjectPath>
#include <QObject>
#include <QVariantMap>
#include <QtQmlIntegration>

#include <memory>

class BluetoothAgent : public QObject, protected QDBusContext
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_CLASSINFO("D-Bus Interface", "org.bluez.Agent1")

    Q_PROPERTY(bool ready READ ready NOTIFY readyChanged)
    Q_PROPERTY(bool hasRequest READ hasRequest NOTIFY requestChanged)
    Q_PROPERTY(QVariantMap request READ request NOTIFY requestChanged)
    Q_PROPERTY(QString lastError READ lastError NOTIFY lastErrorChanged)

public:
    explicit BluetoothAgent(QObject *parent = nullptr);
    ~BluetoothAgent() override;

    bool ready() const;
    bool hasRequest() const;
    QVariantMap request() const;
    QString lastError() const;

    Q_INVOKABLE void initialize();
    Q_INVOKABLE bool respond(bool accepted, const QString &value = {});
    Q_INVOKABLE void dismissDisplay();

public slots:
    void Release();
    QString RequestPinCode(const QDBusObjectPath &device);
    void DisplayPinCode(const QDBusObjectPath &device, const QString &pinCode);
    quint32 RequestPasskey(const QDBusObjectPath &device);
    void DisplayPasskey(const QDBusObjectPath &device, quint32 passkey, quint16 entered);
    void RequestConfirmation(const QDBusObjectPath &device, quint32 passkey);
    void RequestAuthorization(const QDBusObjectPath &device);
    void AuthorizeService(const QDBusObjectPath &device, const QString &uuid);
    void Cancel();

signals:
    void readyChanged();
    void requestChanged();
    void lastErrorChanged();

private:
    class Private;
    std::unique_ptr<Private> d;
};
