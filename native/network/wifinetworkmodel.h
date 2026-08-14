#pragma once

#include <QAbstractListModel>
#include <QList>
#include <QString>
#include <QtQmlIntegration>

// GLib has a public struct member named `signals`, while Qt defines `signals`
// as a keyword macro. Keep that collision local to this one boundary header.
#ifdef signals
#define ATERIA_RESTORE_QT_SIGNALS_KEYWORD
#undef signals
#endif
#include <NetworkManager.h>
#ifdef ATERIA_RESTORE_QT_SIGNALS_KEYWORD
#define signals Q_SIGNALS
#undef ATERIA_RESTORE_QT_SIGNALS_KEYWORD
#endif

struct WifiNetworkEntry
{
    QString id;
    QString ssid;
    QByteArray ssidBytes;
    int strength = 0;
    int security = 0;
    QString securityName;
    bool known = false;
    bool connected = false;
    bool connecting = false;
    bool autoconnect = false;
    bool hidden = false;
    int frequency = 0;
    QString bssid;
    QString deviceName;
    QString profileUuid;
    NMAccessPoint *accessPoint = nullptr;
    NMRemoteConnection *connection = nullptr;

    bool operator==(const WifiNetworkEntry &other) const;
};

class WifiNetworkModel : public QAbstractListModel
{
    Q_OBJECT
    QML_ANONYMOUS
    Q_PROPERTY(int count READ rowCount NOTIFY countChanged)

public:
    enum Role {
        NetworkIdRole = Qt::UserRole + 1,
        SsidRole,
        StrengthRole,
        SecurityRole,
        SecurityNameRole,
        KnownRole,
        ConnectedRole,
        ConnectingRole,
        AutoconnectRole,
        HiddenRole,
        FrequencyRole,
        BssidRole,
        DeviceNameRole,
        ProfileUuidRole,
        CanForgetRole,
    };
    Q_ENUM(Role)

    explicit WifiNetworkModel(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    const WifiNetworkEntry *find(const QString &networkId) const;
    void replace(QList<WifiNetworkEntry> entries);

signals:
    void countChanged();

private:
    QList<WifiNetworkEntry> m_entries;
};
