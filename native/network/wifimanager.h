#pragma once

#include "wifinetworkmodel.h"

#include <QElapsedTimer>
#include <QObject>
#include <QTimer>
#include <QVariantList>
#include <QtQmlIntegration>

class WifiManager : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(bool available READ available NOTIFY availableChanged)
    Q_PROPERTY(bool wifiEnabled READ wifiEnabled NOTIFY wifiEnabledChanged)
    Q_PROPERTY(bool wifiHardwareEnabled READ wifiHardwareEnabled NOTIFY wifiHardwareEnabledChanged)
    Q_PROPERTY(bool scanning READ scanning NOTIFY scanningChanged)
    Q_PROPERTY(bool wifiConnected READ wifiConnected NOTIFY wifiConnectedChanged)
    Q_PROPERTY(bool wiredConnected READ wiredConnected NOTIFY wiredConnectedChanged)
    Q_PROPERTY(bool connected READ connected NOTIFY connectedChanged)
    Q_PROPERTY(int connectivity READ connectivity NOTIFY connectivityChanged)
    Q_PROPERTY(bool hasInternet READ hasInternet NOTIFY connectivityChanged)
    Q_PROPERTY(bool captivePortal READ captivePortal NOTIFY connectivityChanged)
    Q_PROPERTY(bool limitedConnectivity READ limitedConnectivity NOTIFY connectivityChanged)
    Q_PROPERTY(bool canCheckConnectivity READ canCheckConnectivity NOTIFY canCheckConnectivityChanged)
    Q_PROPERTY(QString connectedSsid READ connectedSsid NOTIFY connectedSsidChanged)
    Q_PROPERTY(int connectedStrength READ connectedStrength NOTIFY connectedStrengthChanged)
    Q_PROPERTY(QString selectedDevice READ selectedDevice NOTIFY selectedDeviceChanged)
    Q_PROPERTY(QVariantList wifiDevices READ wifiDevices NOTIFY wifiDevicesChanged)
    Q_PROPERTY(WifiNetworkModel *networks READ networks CONSTANT)
    Q_PROPERTY(WifiNetworkModel *savedNetworks READ savedNetworks CONSTANT)
    Q_PROPERTY(bool operationBusy READ operationBusy NOTIFY operationBusyChanged)
    Q_PROPERTY(QString currentOperation READ currentOperation NOTIFY currentOperationChanged)
    Q_PROPERTY(QString lastError READ lastError NOTIFY lastErrorChanged)

public:
    enum Security {
        Open = 0,
        Wep,
        WpaPersonal,
        Wpa3Personal,
        Owe,
        Enterprise,
        UnknownSecurity,
    };
    Q_ENUM(Security)

    enum Connectivity {
        ConnectivityUnknown = NM_CONNECTIVITY_UNKNOWN,
        ConnectivityNone = NM_CONNECTIVITY_NONE,
        ConnectivityPortal = NM_CONNECTIVITY_PORTAL,
        ConnectivityLimited = NM_CONNECTIVITY_LIMITED,
        ConnectivityFull = NM_CONNECTIVITY_FULL,
    };
    Q_ENUM(Connectivity)

    explicit WifiManager(QObject *parent = nullptr);
    ~WifiManager() override;

    bool available() const { return m_available; }
    bool wifiEnabled() const { return m_wifiEnabled; }
    bool wifiHardwareEnabled() const { return m_wifiHardwareEnabled; }
    bool scanning() const { return m_scanInFlight; }
    bool wifiConnected() const { return m_wifiConnected; }
    bool wiredConnected() const { return m_wiredConnected; }
    bool connected() const { return m_wifiConnected || m_wiredConnected; }
    int connectivity() const { return m_connectivity; }
    bool hasInternet() const { return m_connectivity == NM_CONNECTIVITY_FULL; }
    bool captivePortal() const { return m_connectivity == NM_CONNECTIVITY_PORTAL; }
    bool limitedConnectivity() const { return m_connectivity == NM_CONNECTIVITY_LIMITED; }
    bool canCheckConnectivity() const { return m_canCheckConnectivity; }
    QString connectedSsid() const { return m_connectedSsid; }
    int connectedStrength() const { return m_connectedStrength; }
    QString selectedDevice() const { return m_selectedDevice; }
    QVariantList wifiDevices() const { return m_wifiDevices; }
    WifiNetworkModel *networks() { return &m_networks; }
    WifiNetworkModel *savedNetworks() { return &m_savedNetworks; }
    bool operationBusy() const { return m_operationBusy; }
    QString currentOperation() const { return m_currentOperation; }
    QString lastError() const { return m_lastError; }

    Q_INVOKABLE bool setWifiEnabled(bool enabled);
    Q_INVOKABLE bool selectDevice(const QString &interfaceName);
    Q_INVOKABLE bool requestScan();
    Q_INVOKABLE bool checkConnectivity();
    Q_INVOKABLE bool connectNetwork(const QString &networkId);
    Q_INVOKABLE bool connectNetworkWithPassword(const QString &networkId, const QString &password);
    Q_INVOKABLE bool disconnectNetwork(const QString &networkId);
    Q_INVOKABLE bool forgetNetwork(const QString &networkId);
    Q_INVOKABLE bool setAutoconnect(const QString &networkId, bool enabled);
    Q_INVOKABLE bool addAndConnect(const QString &ssid, const QString &password, int security, bool hidden);
    Q_INVOKABLE void cancelOperation();
    Q_INVOKABLE QString validatePassword(int security, const QString &password) const;
    Q_INVOKABLE QString securityLabel(int security) const;

signals:
    void availableChanged();
    void wifiEnabledChanged();
    void wifiHardwareEnabledChanged();
    void scanningChanged();
    void wifiConnectedChanged();
    void wiredConnectedChanged();
    void connectedChanged();
    void connectivityChanged();
    void canCheckConnectivityChanged();
    void connectedSsidChanged();
    void connectedStrengthChanged();
    void selectedDeviceChanged();
    void wifiDevicesChanged();
    void operationBusyChanged();
    void currentOperationChanged();
    void lastErrorChanged();

    void credentialsRequired(QString networkId, QString ssid, int security);
    void networkConnected(QString networkId, QString ssid);
    void networkDisconnected(QString networkId);
    void networkForgotten(QString networkId);
    void networkAutoconnectChanged(QString networkId, bool enabled);
    void scanFinished(bool success, QString message);
    void operationFailed(QString operation, QString message);

private:
    struct AsyncContext;

    static void handleClientChanged(GObject *object, GParamSpec *property, gpointer userData);
    static void handleObjectChanged(GObject *object, gpointer userData);
    static void handleObjectArgumentChanged(GObject *object, gpointer argument, gpointer userData);
    static void handleScanFinished(GObject *source, GAsyncResult *result, gpointer userData);
    static void handleConnectivityFinished(GObject *source, GAsyncResult *result, gpointer userData);
    static void handleActivationFinished(GObject *source, GAsyncResult *result, gpointer userData);
    static void handleAddActivationFinished(GObject *source, GAsyncResult *result, gpointer userData);
    static void handleDisconnectFinished(GObject *source, GAsyncResult *result, gpointer userData);
    static void handleDeleteFinished(GObject *source, GAsyncResult *result, gpointer userData);
    static void handleCommitFinished(GObject *source, GAsyncResult *result, gpointer userData);

    void initializeClient();
    void connectClientSignals();
    void reconnectObjectSignals(NMDeviceWifi *selectedDevice);
    void clearObjectSignals();
    void scheduleRefresh();
    void refresh();
    void refreshNetworks(NMDeviceWifi *device);
    void refreshSavedNetworks(NMDeviceWifi *device);

    NMDeviceWifi *selectedWifiDevice() const;
    QList<NMDeviceWifi *> wifiDeviceObjects() const;
    const WifiNetworkEntry *network(const QString &networkId) const;
    Security securityForAccessPoint(NMAccessPoint *accessPoint) const;
    Security securityForConnection(NMConnection *connection) const;
    QString displaySsid(GBytes *ssid) const;
    QString networkId(GBytes *ssid, Security security) const;
    NMConnection *createConnection(const QString &ssid,
                                   const QByteArray &ssidBytes,
                                   const QString &password,
                                   Security security,
                                   bool hidden) const;
    bool activateEntry(const WifiNetworkEntry &entry, const QString &password);
    bool activateNew(const QString &id,
                     const QString &ssid,
                     const QByteArray &ssidBytes,
                     const QString &password,
                     Security security,
                     bool hidden,
                     NMAccessPoint *accessPoint);

    bool beginOperation(const QString &operation, const QString &networkId, const QString &ssid);
    void markActivationAccepted();
    void finishOperation();
    void failOperation(const QString &message);
    void setLastError(const QString &message);
    void clearLastError();
    void updateActivationState(NMDeviceWifi *device);
    void emitConnectedSignals(bool oldWifiConnected, bool oldWiredConnected);

    NMClient *m_client = nullptr;
    GCancellable *m_scanCancellable = nullptr;
    GCancellable *m_operationCancellable = nullptr;
    QList<QPair<GObject *, gulong>> m_clientSignalHandlers;
    QList<QPair<GObject *, gulong>> m_objectSignalHandlers;

    WifiNetworkModel m_networks;
    WifiNetworkModel m_savedNetworks;
    QTimer m_refreshTimer;
    QTimer m_activationCheckTimer;
    QTimer m_operationTimeout;
    bool m_available = false;
    bool m_wifiEnabled = false;
    bool m_wifiHardwareEnabled = false;
    bool m_scanInFlight = false;
    bool m_wifiConnected = false;
    bool m_wiredConnected = false;
    bool m_canCheckConnectivity = false;
    bool m_operationBusy = false;
    bool m_activationAccepted = false;
    int m_connectivity = NM_CONNECTIVITY_UNKNOWN;
    int m_connectedStrength = 0;
    QString m_connectedSsid;
    QString m_selectedDevice;
    QString m_preferredDevice;
    QVariantList m_wifiDevices;
    QString m_currentOperation;
    QString m_pendingNetworkId;
    QString m_pendingSsid;
    QString m_lastError;
    quint64 m_operationGeneration = 0;
    QElapsedTimer m_activationElapsed;
};
