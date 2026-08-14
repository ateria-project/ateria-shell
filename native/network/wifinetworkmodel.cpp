#include "wifinetworkmodel.h"

#include <QVariant>

#include <algorithm>

bool WifiNetworkEntry::operator==(const WifiNetworkEntry &other) const
{
    return id == other.id && ssid == other.ssid && ssidBytes == other.ssidBytes
        && strength == other.strength && security == other.security
        && securityName == other.securityName && known == other.known
        && connected == other.connected && connecting == other.connecting
        && autoconnect == other.autoconnect && hidden == other.hidden
        && frequency == other.frequency && bssid == other.bssid
        && deviceName == other.deviceName && profileUuid == other.profileUuid
        && accessPoint == other.accessPoint && connection == other.connection;
}

WifiNetworkModel::WifiNetworkModel(QObject *parent)
    : QAbstractListModel(parent)
{
}

int WifiNetworkModel::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : m_entries.size();
}

QVariant WifiNetworkModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_entries.size())
        return {};

    const WifiNetworkEntry &entry = m_entries.at(index.row());
    switch (role) {
    case NetworkIdRole:
        return entry.id;
    case SsidRole:
        return entry.ssid;
    case StrengthRole:
        return entry.strength;
    case SecurityRole:
        return entry.security;
    case SecurityNameRole:
        return entry.securityName;
    case KnownRole:
        return entry.known;
    case ConnectedRole:
        return entry.connected;
    case ConnectingRole:
        return entry.connecting;
    case AutoconnectRole:
        return entry.autoconnect;
    case HiddenRole:
        return entry.hidden;
    case FrequencyRole:
        return entry.frequency;
    case BssidRole:
        return entry.bssid;
    case DeviceNameRole:
        return entry.deviceName;
    case ProfileUuidRole:
        return entry.profileUuid;
    case CanForgetRole:
        return entry.connection != nullptr;
    default:
        return {};
    }
}

QHash<int, QByteArray> WifiNetworkModel::roleNames() const
{
    return {
        { NetworkIdRole, "networkId" },
        { SsidRole, "ssid" },
        { StrengthRole, "strength" },
        { SecurityRole, "security" },
        { SecurityNameRole, "securityName" },
        { KnownRole, "known" },
        { ConnectedRole, "connected" },
        { ConnectingRole, "connecting" },
        { AutoconnectRole, "autoconnect" },
        { HiddenRole, "hidden" },
        { FrequencyRole, "frequency" },
        { BssidRole, "bssid" },
        { DeviceNameRole, "deviceName" },
        { ProfileUuidRole, "profileUuid" },
        { CanForgetRole, "canForget" },
    };
}

const WifiNetworkEntry *WifiNetworkModel::find(const QString &networkId) const
{
    for (const WifiNetworkEntry &entry : m_entries) {
        if (entry.id == networkId)
            return &entry;
    }
    return nullptr;
}

void WifiNetworkModel::replace(QList<WifiNetworkEntry> entries)
{
    if (m_entries == entries)
        return;

    const int oldCount = m_entries.size();

    // Reconcile by stable ID instead of resetting the model. A model reset
    // destroys every QML delegate, including an open per-network popup.
    for (int row = m_entries.size() - 1; row >= 0; --row) {
        const bool remains = std::any_of(entries.cbegin(), entries.cend(), [this, row](const WifiNetworkEntry &entry) {
            return entry.id == m_entries.at(row).id;
        });
        if (remains)
            continue;

        beginRemoveRows({}, row, row);
        m_entries.removeAt(row);
        endRemoveRows();
    }

    for (int targetRow = 0; targetRow < entries.size(); ++targetRow) {
        const WifiNetworkEntry &newEntry = entries.at(targetRow);
        int currentRow = -1;
        for (int row = targetRow; row < m_entries.size(); ++row) {
            if (m_entries.at(row).id == newEntry.id) {
                currentRow = row;
                break;
            }
        }

        if (currentRow < 0) {
            beginInsertRows({}, targetRow, targetRow);
            m_entries.insert(targetRow, newEntry);
            endInsertRows();
            continue;
        }

        if (currentRow != targetRow) {
            beginMoveRows({}, currentRow, currentRow, {}, targetRow);
            m_entries.move(currentRow, targetRow);
            endMoveRows();
        }

        if (!(m_entries.at(targetRow) == newEntry)) {
            m_entries[targetRow] = newEntry;
            emit dataChanged(index(targetRow), index(targetRow));
        }
    }

    while (m_entries.size() > entries.size()) {
        const int row = m_entries.size() - 1;
        beginRemoveRows({}, row, row);
        m_entries.removeAt(row);
        endRemoveRows();
    }

    if (oldCount != m_entries.size())
        emit countChanged();
}
