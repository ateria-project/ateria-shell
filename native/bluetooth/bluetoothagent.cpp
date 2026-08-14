#include "bluetoothagent.h"

#include <QCoreApplication>
#include <QDBusConnection>
#include <QDBusError>
#include <QDBusInterface>
#include <QDBusMessage>
#include <QDBusPendingCallWatcher>
#include <QDBusPendingReply>
#include <QDBusServiceWatcher>
#include <QRegularExpression>
#include <QTimer>

#include <algorithm>

namespace {

constexpr auto BluezService = "org.bluez";
constexpr auto AgentManagerPath = "/org/bluez";
constexpr auto AgentManagerInterface = "org.bluez.AgentManager1";
constexpr auto AgentPath = "/org/ateria/BluetoothAgent";
constexpr auto AgentCapability = "KeyboardDisplay";
constexpr auto RejectedError = "org.bluez.Error.Rejected";
constexpr auto CanceledError = "org.bluez.Error.Canceled";

QString registrationError(const QDBusError &error)
{
    const auto message = [](const char *text) {
        return QCoreApplication::translate("BluetoothAgent", text);
    };
    if (error.type() == QDBusError::ServiceUnknown || error.type() == QDBusError::Disconnected)
        return message("The Bluetooth service is not available.");
    if (error.type() == QDBusError::AccessDenied || error.name().contains(QStringLiteral("NotAuthorized")))
        return message("You do not have permission to register the Bluetooth pairing agent.");
    if (error.type() == QDBusError::NoReply || error.type() == QDBusError::Timeout)
        return message("The Bluetooth service did not respond. Retrying shortly.");
    if (error.name().contains(QStringLiteral("AlreadyExists")))
        return message("A Bluetooth pairing agent is already registered on this connection.");
    return message("Could not register the Bluetooth pairing agent.");
}

QString paddedPasskey(quint32 passkey)
{
    return QStringLiteral("%1").arg(passkey, 6, 10, QLatin1Char('0'));
}

} // namespace

class BluetoothAgent::Private
{
public:
    enum class ReplyKind : quint8 {
        None,
        PinCode,
        Passkey,
        Confirmation,
        Authorization,
        ServiceAuthorization,
    };

    explicit Private(BluetoothAgent *agent)
        : q(agent)
        , bus(QDBusConnection::systemBus())
        , serviceWatcher(QString::fromLatin1(BluezService),
                         bus,
                         QDBusServiceWatcher::WatchForOwnerChange,
                         agent)
    {
        registrationRetry.setSingleShot(true);
        requestTimeout.setSingleShot(true);
        requestTimeout.setInterval(120000);

        QObject::connect(&registrationRetry, &QTimer::timeout, q, [this] { registerAgent(); });
        QObject::connect(&requestTimeout, &QTimer::timeout, q, [this] {
            finishPending(QString::fromLatin1(CanceledError),
                          QCoreApplication::translate("BluetoothAgent", "The pairing request timed out."));
        });
        QObject::connect(&serviceWatcher,
                         &QDBusServiceWatcher::serviceOwnerChanged,
                         q,
                         [this](const QString &, const QString &, const QString &newOwner) {
                             ++registrationGeneration;
                             registrationRetry.stop();
                             registered = false;
                             registrationInFlight = false;
                             setReady(false);
                             clearPendingWithoutReply();
                             clearRequest();
                             if (initialized && !newOwner.isEmpty())
                                 scheduleRegistration(100);
                         });
    }

    BluetoothAgent *q;
    QDBusConnection bus;
    QDBusServiceWatcher serviceWatcher;
    QTimer registrationRetry;
    QTimer requestTimeout;
    bool initialized = false;
    bool objectRegistered = false;
    bool registered = false;
    bool registrationInFlight = false;
    bool ready = false;
    int registrationAttempts = 0;
    quint64 registrationGeneration = 0;
    QString lastError;
    QVariantMap request;
    quint64 nextRequestId = 1;
    quint64 pendingRequestId = 0;
    ReplyKind pendingKind = ReplyKind::None;
    QDBusMessage pendingCall;
    QDBusConnection pendingConnection = QDBusConnection::systemBus();

    void initialize()
    {
        if (initialized)
            return;
        initialized = true;
        if (!bus.isConnected()) {
            setError(QCoreApplication::translate("BluetoothAgent", "The system message bus is not available."));
            scheduleRegistration(1000);
            return;
        }
        if (!ensureObjectRegistered())
            return;
        registerAgent();
    }

    bool ensureObjectRegistered()
    {
        if (objectRegistered)
            return true;
        objectRegistered = bus.registerObject(QString::fromLatin1(AgentPath),
                                              q,
                                              QDBusConnection::ExportAllSlots);
        if (!objectRegistered) {
            setError(QCoreApplication::translate("BluetoothAgent",
                                                 "Could not expose the Bluetooth pairing agent on D-Bus."));
        }
        return objectRegistered;
    }

    void shutdown()
    {
        initialized = false;
        ++registrationGeneration;
        registrationRetry.stop();
        requestTimeout.stop();
        if (pendingKind != ReplyKind::None) {
            finishPending(QString::fromLatin1(CanceledError),
                          QCoreApplication::translate("BluetoothAgent", "The pairing agent stopped."));
        }
        if (registered && bus.isConnected()) {
            QDBusInterface manager(QString::fromLatin1(BluezService),
                                   QString::fromLatin1(AgentManagerPath),
                                   QString::fromLatin1(AgentManagerInterface),
                                   bus);
            manager.call(QDBus::NoBlock,
                         QStringLiteral("UnregisterAgent"),
                         QVariant::fromValue(QDBusObjectPath(QString::fromLatin1(AgentPath))));
        }
        if (objectRegistered)
            bus.unregisterObject(QString::fromLatin1(AgentPath));
        objectRegistered = false;
        registered = false;
        setReady(false);
        clearRequest();
    }

    void registerAgent()
    {
        if (!initialized || registrationInFlight || ready)
            return;
        if (!bus.isConnected()) {
            setError(QCoreApplication::translate("BluetoothAgent", "The system message bus is not available."));
            scheduleRegistration();
            return;
        }
        // initialize() can run before the system bus is available. Complete
        // the object registration here when a later retry reaches the bus.
        if (!ensureObjectRegistered())
            return;

        if (registered) {
            requestDefaultAgent();
            return;
        }

        QDBusInterface manager(QString::fromLatin1(BluezService),
                               QString::fromLatin1(AgentManagerPath),
                               QString::fromLatin1(AgentManagerInterface),
                               bus);
        if (!manager.isValid()) {
            setError(QCoreApplication::translate("BluetoothAgent", "The Bluetooth service is not available."));
            scheduleRegistration();
            return;
        }

        registrationInFlight = true;
        const quint64 generation = registrationGeneration;
        auto *watcher = new QDBusPendingCallWatcher(
            manager.asyncCall(QStringLiteral("RegisterAgent"),
                              QVariant::fromValue(QDBusObjectPath(QString::fromLatin1(AgentPath))),
                              QString::fromLatin1(AgentCapability)),
            q);
        QObject::connect(watcher, &QDBusPendingCallWatcher::finished, q, [this, watcher, generation] {
            const QDBusPendingReply<> reply = *watcher;
            watcher->deleteLater();
            if (!initialized || generation != registrationGeneration)
                return;
            registrationInFlight = false;
            if (reply.isError()) {
                if (reply.error().name().contains(QStringLiteral("AlreadyExists"))) {
                    registered = true;
                    requestDefaultAgent();
                    return;
                }
                setReady(false);
                setError(registrationError(reply.error()));
                scheduleRegistration();
                return;
            }
            registered = true;
            requestDefaultAgent();
        });
    }

    void requestDefaultAgent()
    {
        if (!initialized || registrationInFlight || !registered)
            return;
        QDBusInterface manager(QString::fromLatin1(BluezService),
                               QString::fromLatin1(AgentManagerPath),
                               QString::fromLatin1(AgentManagerInterface),
                               bus);
        if (!manager.isValid()) {
            registered = false;
            setReady(false);
            setError(QCoreApplication::translate("BluetoothAgent", "The Bluetooth service is not available."));
            scheduleRegistration();
            return;
        }

        registrationInFlight = true;
        const quint64 generation = registrationGeneration;
        auto *watcher = new QDBusPendingCallWatcher(
            manager.asyncCall(QStringLiteral("RequestDefaultAgent"),
                              QVariant::fromValue(QDBusObjectPath(QString::fromLatin1(AgentPath)))),
            q);
        QObject::connect(watcher, &QDBusPendingCallWatcher::finished, q, [this, watcher, generation] {
            const QDBusPendingReply<> reply = *watcher;
            watcher->deleteLater();
            if (!initialized || generation != registrationGeneration)
                return;
            registrationInFlight = false;
            if (reply.isError()) {
                if (reply.error().name().contains(QStringLiteral("DoesNotExist")))
                    registered = false;
                setReady(false);
                setError(registrationError(reply.error()));
                scheduleRegistration();
                return;
            }
            registrationAttempts = 0;
            setError({});
            setReady(true);
        });
    }

    void scheduleRegistration(int explicitDelay = -1)
    {
        if (!initialized)
            return;
        const int delay = explicitDelay >= 0
            ? explicitDelay
            : std::min(30000, 1000 * (1 << std::min(registrationAttempts, 5)));
        ++registrationAttempts;
        registrationRetry.start(delay);
    }

    void setReady(bool value)
    {
        if (ready == value)
            return;
        ready = value;
        emit q->readyChanged();
    }

    void setError(const QString &value)
    {
        if (lastError == value)
            return;
        lastError = value;
        emit q->lastErrorChanged();
    }

    QVariantMap deviceDetails(const QString &path) const
    {
        // BluetoothService already owns Quickshell's live BlueZ device model
        // and enriches this request by object path. Avoid a blocking GetAll
        // call here: the device can disappear while BlueZ is requesting user
        // input, and the D-Bus default timeout would otherwise freeze the UI.
        return {{QStringLiteral("path"), path},
                {QStringLiteral("name"),
                 QCoreApplication::translate("BluetoothAgent", "Bluetooth device")},
                {QStringLiteral("address"), QString()}};
    }

    void beginRequest(ReplyKind kind,
                      const QDBusObjectPath &device,
                      const QDBusConnection &callConnection,
                      const QDBusMessage &call,
                      const QVariantMap &fields = {})
    {
        pendingKind = kind;
        pendingCall = call;
        pendingConnection = callConnection;
        pendingRequestId = nextRequestId++;
        QVariantMap next = deviceDetails(device.path());
        next.insert(QStringLiteral("event"), QStringLiteral("request"));
        next.insert(QStringLiteral("id"), pendingRequestId);
        for (auto iterator = fields.cbegin(); iterator != fields.cend(); ++iterator)
            next.insert(iterator.key(), iterator.value());
        setRequest(next);
        requestTimeout.start();
    }

    void showDisplay(const QDBusObjectPath &device,
                     const QString &type,
                     const QVariantMap &fields)
    {
        // Keep an actionable request visible if BlueZ unexpectedly sends a
        // display update while waiting for user input.
        if (pendingKind != ReplyKind::None)
            return;
        QVariantMap next = deviceDetails(device.path());
        next.insert(QStringLiteral("event"), QStringLiteral("display"));
        next.insert(QStringLiteral("type"), type);
        for (auto iterator = fields.cbegin(); iterator != fields.cend(); ++iterator)
            next.insert(iterator.key(), iterator.value());
        setRequest(next);
    }

    bool respond(bool accepted, const QString &value)
    {
        if (pendingKind == ReplyKind::None)
            return false;
        if (!accepted) {
            finishPending(QString::fromLatin1(RejectedError),
                          QCoreApplication::translate("BluetoothAgent", "The pairing request was rejected."));
            return true;
        }

        QVariantList arguments;
        switch (pendingKind) {
        case ReplyKind::PinCode:
            if (value.isEmpty() || value.size() > 16) {
                finishPending(QString::fromLatin1(RejectedError),
                              QCoreApplication::translate("BluetoothAgent", "A valid PIN code is required."));
                return true;
            }
            arguments.append(value);
            break;
        case ReplyKind::Passkey: {
            static const QRegularExpression digits(QStringLiteral("^[0-9]{1,6}$"));
            if (!digits.match(value).hasMatch()) {
                finishPending(QString::fromLatin1(RejectedError),
                              QCoreApplication::translate("BluetoothAgent",
                                                          "The passkey must contain up to six digits."));
                return true;
            }
            arguments.append(value.toUInt());
            break;
        }
        case ReplyKind::Confirmation:
        case ReplyKind::Authorization:
        case ReplyKind::ServiceAuthorization:
            break;
        case ReplyKind::None:
            return false;
        }
        finishPending({}, {}, arguments);
        return true;
    }

    void finishPending(const QString &errorName,
                       const QString &errorMessage,
                       const QVariantList &arguments = {})
    {
        if (pendingKind == ReplyKind::None)
            return;
        requestTimeout.stop();
        if (pendingConnection.isConnected()) {
            const QDBusMessage reply = errorName.isEmpty()
                ? pendingCall.createReply(arguments)
                : pendingCall.createErrorReply(errorName, errorMessage);
            pendingConnection.send(reply);
        }
        const quint64 completedId = pendingRequestId;
        pendingKind = ReplyKind::None;
        pendingCall = {};
        pendingConnection = bus;
        pendingRequestId = 0;
        if (request.value(QStringLiteral("id")).toULongLong() == completedId)
            clearRequest();
    }

    void clearPendingWithoutReply()
    {
        requestTimeout.stop();
        pendingKind = ReplyKind::None;
        pendingCall = {};
        pendingConnection = bus;
        pendingRequestId = 0;
    }

    void setRequest(const QVariantMap &value)
    {
        if (request == value)
            return;
        request = value;
        emit q->requestChanged();
    }

    void clearRequest()
    {
        setRequest({});
    }

    void release()
    {
        if (pendingKind != ReplyKind::None) {
            finishPending(QString::fromLatin1(CanceledError),
                          QCoreApplication::translate("BluetoothAgent", "The pairing request was canceled."));
        }
        ++registrationGeneration;
        registered = false;
        registrationInFlight = false;
        setReady(false);
        clearRequest();
        scheduleRegistration(1000);
    }
};

BluetoothAgent::BluetoothAgent(QObject *parent)
    : QObject(parent)
    , d(std::make_unique<Private>(this))
{
}

BluetoothAgent::~BluetoothAgent()
{
    d->shutdown();
}

bool BluetoothAgent::ready() const
{
    return d->ready;
}

bool BluetoothAgent::hasRequest() const
{
    return !d->request.isEmpty();
}

QVariantMap BluetoothAgent::request() const
{
    return d->request;
}

QString BluetoothAgent::lastError() const
{
    return d->lastError;
}

void BluetoothAgent::initialize()
{
    d->initialize();
}

bool BluetoothAgent::respond(bool accepted, const QString &value)
{
    return d->respond(accepted, value);
}

void BluetoothAgent::dismissDisplay()
{
    if (d->request.value(QStringLiteral("event")).toString() == QStringLiteral("display"))
        d->clearRequest();
}

void BluetoothAgent::Release()
{
    d->release();
}

QString BluetoothAgent::RequestPinCode(const QDBusObjectPath &device)
{
    if (d->pendingKind != Private::ReplyKind::None) {
        sendErrorReply(QString::fromLatin1(CanceledError),
                       QCoreApplication::translate("BluetoothAgent", "Another pairing request is already active."));
        return {};
    }
    setDelayedReply(true);
    d->beginRequest(Private::ReplyKind::PinCode,
                    device,
                    connection(),
                    message(),
                    {{QStringLiteral("type"), QStringLiteral("pinCode")}});
    return {};
}

void BluetoothAgent::DisplayPinCode(const QDBusObjectPath &device, const QString &pinCode)
{
    d->showDisplay(device,
                   QStringLiteral("pinCode"),
                   {{QStringLiteral("value"), pinCode}});
}

quint32 BluetoothAgent::RequestPasskey(const QDBusObjectPath &device)
{
    if (d->pendingKind != Private::ReplyKind::None) {
        sendErrorReply(QString::fromLatin1(CanceledError),
                       QCoreApplication::translate("BluetoothAgent", "Another pairing request is already active."));
        return 0;
    }
    setDelayedReply(true);
    d->beginRequest(Private::ReplyKind::Passkey,
                    device,
                    connection(),
                    message(),
                    {{QStringLiteral("type"), QStringLiteral("passkey")}});
    return 0;
}

void BluetoothAgent::DisplayPasskey(const QDBusObjectPath &device, quint32 passkey, quint16 entered)
{
    d->showDisplay(device,
                   QStringLiteral("passkey"),
                   {{QStringLiteral("value"), paddedPasskey(passkey)},
                    {QStringLiteral("entered"), entered}});
}

void BluetoothAgent::RequestConfirmation(const QDBusObjectPath &device, quint32 passkey)
{
    if (d->pendingKind != Private::ReplyKind::None) {
        sendErrorReply(QString::fromLatin1(CanceledError),
                       QCoreApplication::translate("BluetoothAgent", "Another pairing request is already active."));
        return;
    }
    setDelayedReply(true);
    d->beginRequest(Private::ReplyKind::Confirmation,
                    device,
                    connection(),
                    message(),
                    {{QStringLiteral("type"), QStringLiteral("confirmation")},
                     {QStringLiteral("value"), paddedPasskey(passkey)}});
}

void BluetoothAgent::RequestAuthorization(const QDBusObjectPath &device)
{
    if (d->pendingKind != Private::ReplyKind::None) {
        sendErrorReply(QString::fromLatin1(CanceledError),
                       QCoreApplication::translate("BluetoothAgent", "Another pairing request is already active."));
        return;
    }
    setDelayedReply(true);
    d->beginRequest(Private::ReplyKind::Authorization,
                    device,
                    connection(),
                    message(),
                    {{QStringLiteral("type"), QStringLiteral("authorization")}});
}

void BluetoothAgent::AuthorizeService(const QDBusObjectPath &device, const QString &uuid)
{
    if (d->pendingKind != Private::ReplyKind::None) {
        sendErrorReply(QString::fromLatin1(CanceledError),
                       QCoreApplication::translate("BluetoothAgent", "Another pairing request is already active."));
        return;
    }
    setDelayedReply(true);
    d->beginRequest(Private::ReplyKind::ServiceAuthorization,
                    device,
                    connection(),
                    message(),
                    {{QStringLiteral("type"), QStringLiteral("serviceAuthorization")},
                     {QStringLiteral("uuid"), uuid}});
}

void BluetoothAgent::Cancel()
{
    if (d->pendingKind != Private::ReplyKind::None) {
        d->finishPending(QString::fromLatin1(CanceledError),
                         QCoreApplication::translate("BluetoothAgent", "The pairing request was canceled."));
    } else {
        d->clearRequest();
    }
}
